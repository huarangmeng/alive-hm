/**
 * 服务卡片UI组件
 * 通过卡片保持与应用的通信，实现保活功能
 */
import { XLog } from '../../utils/XLog';

const TAG = 'WidgetCard';

let storageUpdateByStatus = new LocalStorage();

@Entry(storageUpdateByStatus)
@Component
struct WidgetCard {
  @Watch('onActionChange') @LocalStorageProp('widget_card_action') action: string = '';

  /**
   * 监听action变化，触发与EntryAbility的通信
   */
  onActionChange(): void {
    XLog.i(TAG, `卡片action变化 action=${this.action}`);

    postCardAction(this, {
      action: 'call',
      abilityName: 'EntryAbility',
      params: {
        method: 'onUpdateForm',
        timestamp: Date.now()
      }
    });
  }

  aboutToAppear(): void {
    XLog.i(TAG, '卡片即将显示');
  }

  aboutToDisappear(): void {
    XLog.i(TAG, '卡片即将消失');
  }

  build() {
    Column() {
      // 卡片标题
      Text('保活服务')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ bottom: 8 })

      // 状态指示器
      Row() {
        Circle({ width: 8, height: 8 })
          .fill('#00CC66')
        Text('运行中')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ left: 6 })
      }
      .margin({ top: 8 })

      // 提示文本
      Text('点击卡片唤醒应用')
        .fontSize(10)
        .fontColor('#999999')
        .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F5F5')
    .borderRadius(16)
    .onClick(() => {
      XLog.i(TAG, '卡片被点击');
      postCardAction(this, {
        action: 'call',
        abilityName: 'EntryAbility',
        params: {
          method: 'onCardClick',
          timestamp: Date.now()
        }
      });
    })
  }
}
