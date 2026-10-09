/**
 * 音频保活模块
 * 通过静音循环播放音频保持应用后台运行
 * 核心机制：
 * 1. AVPlayer 静音循环播放网络音频
 * 2. AVSession 音频会话管理
 * 3. BackgroundTaskManager 长时后台任务
 */
import { media } from '@kit.MediaKit';
import { WantAgent, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { avSession } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { XLog } from '../utils/XLog';

const TAG = 'AudioPlayer';

export class AudioPlayer {
  private avPlayer?: media.AVPlayer;
  private session: avSession.AVSession | null = null;
  private static instance: AudioPlayer;
  private currentTime: number = 0;
  private aliveCheckInterval?: number;
  private bundleName: string = '';
  isRunning: boolean = false;

  private constructor() {
  }

  static getInstance(): AudioPlayer {
    if (!AudioPlayer.instance) {
      AudioPlayer.instance = new AudioPlayer();
    }
    return AudioPlayer.instance;
  }

  /**
   * 启动音频保活
   * @param context 上下文
   * @param url 音频URL（建议使用短小的音频文件）
   * @param bundleName 应用包名
   */
  async start(context: Context, url: string, bundleName: string): Promise<void> {
    XLog.i(TAG, `启动音频保活 url=${url} bundleName=${bundleName}`);
    this.bundleName = bundleName;

    // 启动进程存活验证定时器
    this.startAliveCheck();

    // 启动音频播放
    await this.startAudio(context, url);
  }

  /**
   * 停止音频保活
   */
  async stop(context: Context): Promise<void> {
    XLog.i(TAG, '停止音频保活');

    // 清除定时器
    if (this.aliveCheckInterval) {
      clearInterval(this.aliveCheckInterval);
      this.aliveCheckInterval = undefined;
    }

    // 停止音频播放
    try {
      if (this.avPlayer) {
        await this.avPlayer.stop();
        await this.avPlayer.release();
        this.avPlayer = undefined;
      }
    } catch (error) {
      XLog.e(TAG, `停止音频播放失败 error=${XLog.toJson(error)}`);
    }

    // 停止会话
    try {
      if (this.session) {
        await this.session.deactivate();
        await this.session.destroy();
        this.session = null;
      }
    } catch (error) {
      XLog.e(TAG, `停止会话失败 error=${XLog.toJson(error)}`);
    }
  }

  /**
   * 启动进程存活验证定时器
   */
  private startAliveCheck(): void {
    this.aliveCheckInterval = setInterval(() => {
      XLog.d(TAG, '进程存活验证 ✓');
    }, 5000); // 每5秒验证一次
  }

  /**
   * 启动音频播放
   */
  private async startAudio(context: Context, url: string): Promise<void> {
    try {
      XLog.i(TAG, '创建AVPlayer');
      this.avPlayer = await media.createAVPlayer();

      // 监听播放进度
      this.avPlayer.on('timeUpdate', (time: number) => {
        this.currentTime = time;
        this.isRunning = true;
      });

      // 监听状态变化
      this.avPlayer.on('stateChange', async (state: media.AVPlayerState, reason: media.StateChangeReason) => {
        XLog.i(TAG, `AVPlayer状态变化 state=${state} reason=${reason}`);

        switch (state) {
          case 'initialized':
            await this.avPlayer?.prepare();
            break;
          case 'prepared':
            if (this.avPlayer) {
              // 设置音频中断模式为共享模式（不会被其他音频打断）
              this.avPlayer.audioInterruptMode = audio.InterruptMode.SHARE_MODE;
              // 开启循环播放
              this.avPlayer.loop = true;
              // 静音播放
              await this.avPlayer.setMediaMuted(media.MediaType.MEDIA_TYPE_AUD, true);
            }
            await this.avPlayer?.play();
            break;

          case 'playing':
            XLog.i(TAG, '音频开始播放');
            // 创建音频会话
            await this.createSession(context);
            this.isRunning = true;
            break;
          case 'released':
            this.isRunning = false;
            break;
          case 'error':
            this.isRunning = false;
            XLog.e(TAG, `AVPlayer错误 reason=${reason}`);
            break;
        }
      });

      // 监听错误
      this.avPlayer.on('error', (error: BusinessError) => {
        XLog.e(TAG, `AVPlayer播放错误 code=${error.code} message=${error.message}`);
      });

      // 设置音频URL
      this.avPlayer.url = url;
      XLog.i(TAG, 'AVPlayer URL已设置');
    } catch (error) {
      XLog.e(TAG, `启动音频播放失败 error=${XLog.toJson(error)}`, error);
    }
  }

  /**
   * 创建音频会话
   */
  private async createSession(context: Context): Promise<void> {
    try {
      if (this.session) {
        XLog.w(TAG, '会话已存在，跳过创建');
        return;
      }

      XLog.i(TAG, '创建AVSession');
      this.session = await avSession.createAVSession(context, 'keepalive_session', 'audio');
      await this.session.activate();
      XLog.i(TAG, 'AVSession已激活');
    } catch (error) {
      XLog.e(TAG, `创建音频会话失败 error=${XLog.toJson(error)}`, error);
    }
  }

  /**
   * 启动长时后台任务
   */
  private async startContinuousTask(context: Context): Promise<void> {
    try {
      XLog.i(TAG, '准备启动长时后台任务');

      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: this.bundleName,
            abilityName: 'EntryAbility'
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 100,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      const wantAgentObj: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);
      XLog.d(TAG, 'WantAgent已创建');

      await backgroundTaskManager.startBackgroundRunning(
        context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        wantAgentObj
      );

      XLog.i(TAG, '长时后台任务已启动 ✓');
    } catch (error) {
      XLog.e(TAG, `启动长时后台任务失败 error=${XLog.toJson(error)}`, error);
    }
  }
}
