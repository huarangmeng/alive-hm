/**
 * 表单扩展能力（服务卡片）
 * 管理服务卡片的生命周期和事件处理
 */
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { XLog } from '../utils/XLog';

const TAG = 'EntryFormAbility';

export default class EntryFormAbility extends FormExtensionAbility {
  /**
   * 卡片添加时触发
   */
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string;
    XLog.i(TAG, `onAddForm 卡片被添加 formId=${formId}`);

    const formData = {
      'title': '保活服务卡片',
      'status': '运行中',
      'widget_card_action': 'onAddForm',
      'timestamp': Date.now().toString()
    } as Record<string, string>;

    return formBindingData.createFormBindingData(formData);
  }

  /**
   * 卡片事件处理
   */
  onFormEvent(formId: string, message: string): void {
    XLog.i(TAG, `onFormEvent 卡片事件 formId=${formId} message=${message}`);
  }

  /**
   * 卡片更新时触发
   */
  onUpdateForm(formId: string): void {
    XLog.i(TAG, `onUpdateForm 卡片更新 formId=${formId}`);

    // 可以在这里更新卡片数据
    const formData = {
      'status': '运行中',
      'widget_card_action': 'onUpdateForm: ' + new Date().toLocaleTimeString(),
      'updateTime': new Date().toLocaleTimeString()
    } as Record<string, string>;

    try {
      const updateData = formBindingData.createFormBindingData(formData);
      formProvider.updateForm(formId, updateData)
      XLog.d(TAG, `卡片数据已准备 data=${XLog.toJson(formData)}`);
    } catch (error) {
      XLog.e(TAG, `更新卡片数据失败 error=${XLog.toJson(error)}`);
    }
  }

  /**
   * 卡片转换为普通卡片
   */
  onCastToNormalForm(formId: string): void {
    XLog.i(TAG, `onCastToNormalForm 卡片转换 formId=${formId}`);
  }

  /**
   * 卡片可见性变化
   */
  onChangeFormVisibility(newStatus: Record<string, number>): void {
    XLog.i(TAG, `onChangeFormVisibility 可见性变化 status=${XLog.toJson(newStatus)}`);
  }

  /**
   * 获取卡片状态
   */
  onAcquireFormState(want: Want): formInfo.FormState {
    XLog.i(TAG, 'onAcquireFormState 查询卡片状态');
    return formInfo.FormState.READY;
  }

  /**
   * 卡片删除时触发
   */
  onRemoveForm(formId: string): void {
    XLog.i(TAG, `onRemoveForm 卡片被删除 formId=${formId}`);
  }

  /**
   * 卡片提供方销毁
   */
  onDestroy(): void {
    XLog.i(TAG, 'onDestroy 卡片服务销毁');
  }
}
