import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AudioPlayer } from '../keepalive/AudioPlayer';
import { XLog } from '../utils/XLog';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  private audioPlayer?: AudioPlayer;
  private aliveCheckInterval?: number;
  private isBackground: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    XLog.i(TAG,
      `Ability onCreate launchReason=${launchParam.launchReason} lastExitReason=${launchParam.lastExitReason}`);

    // 检查是否为后台启动
    const isBackgroundCall = want.parameters?.['IS_BACKGROUND_CALL'] as boolean;
    if (isBackgroundCall) {
      XLog.i(TAG, '后台启动模式');
    }

    this.context.getApplicationContext().setSupportedProcessCache(true);

    // 启动进程存活验证
    this.startAliveCheck();
  }

  onDestroy(): void {
    XLog.i(TAG, 'Ability onDestroy');

    // 清理定时器
    if (this.aliveCheckInterval) {
      clearInterval(this.aliveCheckInterval);
    }

    // 停止音频保活
    if (this.audioPlayer) {
      this.audioPlayer.stop(this.context).catch((err: BusinessError<void>) => {
        XLog.e(TAG, `停止音频保活失败 error=${XLog.toJson(err)}`, err);
      });
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    XLog.i(TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        XLog.e(TAG, `加载页面失败 error=${XLog.toJson(err)}`);
        return;
      }
      XLog.i(TAG, '页面加载成功');
    });
  }

  onWindowStageDestroy(): void {
    XLog.i(TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    XLog.i(TAG, 'Ability onForeground');
    this.isBackground = false;
  }

  onBackground(): void {
    XLog.i(TAG, 'Ability onBackground');
    this.isBackground = true;

    // 在后台时启动音频保活
    this.startAudioKeepAlive();
  }

  /**
   * 启动音频保活
   */
  private startAudioKeepAlive(): void {
    if (this.audioPlayer) {
      XLog.w(TAG, '音频保活已在运行');
      return;
    }

    try {
      this.audioPlayer = AudioPlayer.getInstance();
      const bundleName = this.context.applicationInfo.name || 'com.hrm.alive.hm';
      // 使用一个短小的在线音频文件
      const audioUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

      this.audioPlayer.start(this.context, audioUrl, bundleName)
        .then(() => {
          XLog.i(TAG, '音频保活启动成功');
        })
        .catch((err: BusinessError<void>) => {
          XLog.e(TAG, `音频保活启动失败 error=${XLog.toJson(err)}`, err);
        });
    } catch (error) {
      XLog.e(TAG, `启动音频保活异常 error=${XLog.toJson(error)}`);
    }
  }

  /**
   * 启动进程存活验证定时器
   */
  private startAliveCheck(): void {
    this.aliveCheckInterval = setInterval(() => {
      XLog.d(TAG, `EntryAbility 进程存活验证 ✓, 当前处于 ${this.isBackground ? '后台' : '前台'}`);
    }, 10000); // 每10秒验证一次
  }
}
