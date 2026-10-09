import { AudioPlayer } from '../keepalive/AudioPlayer';
import { XLog } from '../utils/XLog';

const TAG = 'Index';

@Entry
@ComponentV2
struct Index {
  @Local isKeepAliveRunning: boolean = AudioPlayer.getInstance().isRunning;
  private audioPlayer?: AudioPlayer;

  aboutToAppear(): void {
    XLog.i(TAG, 'Index页面加载');
  }

  build() {
    Column() {
      // 标题
      Text('应用保活服务')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 60, bottom: 40 })

      // 状态显示
      Row() {
        Circle({ width: 12, height: 12 })
          .fill(this.isKeepAliveRunning ? '#00CC66' : '#999999')
          .margin({ right: 8 })

        Text(this.isKeepAliveRunning ? '保活服务运行中' : '保活服务未启动')
          .fontSize(16)
          .fontColor(this.isKeepAliveRunning ? '#00CC66' : '#999999')
      }
      .margin({ bottom: 40 })

      // 启动按钮
      Button(this.isKeepAliveRunning ? '停止保活' : '启动保活')
        .width('80%')
        .height(50)
        .fontSize(18)
        .backgroundColor(this.isKeepAliveRunning ? '#FF6666' : '#007DFF')
        .margin({ bottom: 20 })
        .onClick(() => {
          this.toggleKeepAlive();
        })

      // 说明文本
      Text('保活机制说明：')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 40, bottom: 16 })
        .alignSelf(ItemAlign.Start)
        .margin({ left: 40 })

      Column({ space: 12 }) {
        this.infoItem('1. 音频保活', '静音循环播放音频保持后台运行')
        this.infoItem('2. 服务卡片', '通过桌面卡片保持应用活跃')
        this.infoItem('3. 长时任务', '申请后台长时运行权限')
      }
      .width('80%')
      .alignItems(HorizontalAlign.Start)

      // 提示
      Text('提示：将服务卡片添加到桌面以增强保活效果')
        .fontSize(12)
        .fontColor('#999999')
        .margin({ top: 40 })
        .textAlign(TextAlign.Center)
        .width('80%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  infoItem(title: string, desc: string) {
    Row() {
      Text('• ')
        .fontSize(14)
        .fontColor('#333333')
      Column({ space: 4 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        Text(desc)
          .fontSize(12)
          .fontColor('#666666')
      }
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Top)
  }

  /**
   * 切换保活状态
   */
  private toggleKeepAlive(): void {
    if (this.isKeepAliveRunning) {
      this.stopKeepAlive();
    } else {
      this.startKeepAlive();
    }
  }

  /**
   * 启动保活
   */
  private startKeepAlive(): void {
    XLog.i(TAG, '用户启动保活');

    try {
      this.audioPlayer = AudioPlayer.getInstance();
      const context = getContext(this) as Context;
      const bundleName = context.applicationInfo.name || 'com.hrm.alive.hm';
      const audioUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

      this.audioPlayer.start(context, audioUrl, bundleName)
        .then(() => {
          XLog.i(TAG, '保活启动成功');
          this.isKeepAliveRunning = true;
        })
        .catch((err: BusinessError<void>) => {
          XLog.e(TAG, `保活启动失败 error=${XLog.toJson(err)}`);
        });
    } catch (error) {
      XLog.e(TAG, `启动保活异常 error=${XLog.toJson(error)}`);
    }
  }

  /**
   * 停止保活
   */
  private stopKeepAlive(): void {
    XLog.i(TAG, '用户停止保活');

    if (this.audioPlayer) {
      const context = getContext(this) as Context;
      this.audioPlayer.stop(context)
        .then(() => {
          XLog.i(TAG, '保活停止成功');
          this.isKeepAliveRunning = false;
        })
        .catch((err: BusinessError<void>) => {
          XLog.e(TAG, `保活停止失败 error=${XLog.toJson(err)}`);
        });
    }
  }
}
