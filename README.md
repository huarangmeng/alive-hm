# HarmonyOS 保活示例

本项目探索两种保活方式：利用 Widget（桌面服务卡片）的更新机制自动拉活，以及通过静音循环播放音乐维持后台运行。两者作用不同：Widget 提供系统触发的执行机会，音频方案用于延长已启动应用的后台运行时间。

## 1. Widget 自动拉活

用户将服务卡片添加到桌面后，系统按卡片更新配置调度更新，并调用卡片提供方 `EntryFormAbility.onUpdateForm()`。设计思路是借助这次系统回调，在需要时获得进程执行机会，而不是依赖应用自己的定时器持续运行。

### 定点刷新与周期刷新

两种刷新方案均可使用，关键是由系统触发 `EntryFormAbility.onUpdateForm(formId)`，获得执行卡片更新逻辑的机会。需要开启 `updateEnabled`。

| 参数 | 类型 | 含义 | 缺省值 |
| --- | --- | --- | --- |
| `scheduledUpdateTime` | 字符串 | 定点刷新的时刻，采用 24 小时制，精确到分钟，例如 `"16:45"`。 | `"0:0"`；缺省时不进行定点刷新。 |
| `updateDuration` | 数值 | 定时刷新的更新周期，单位为 30 分钟，取值为自然数。`0` 表示不生效；正整数 `N` 表示周期为 `30 × N` 分钟。 | `0` |

**优先级：** 生效的 `updateDuration` 配置优先于 `scheduledUpdateTime`。两者同时配置且 `updateDuration > 0` 时，以 `updateDuration` 的刷新周期为准；要使用定点刷新，应省略 `updateDuration` 或将其设为 `0`。

定点刷新示例（本项目当前配置）：

```json
{
  "updateEnabled": true,
  "scheduledUpdateTime": "16:45"
}
```

周期刷新示例（每 30 分钟）：

```json
{
  "updateEnabled": true,
  "updateDuration": 1
}
```

上述时刻和周期是系统调度配置，实际回调时间仍需通过日志验证。

### 更新回调与主应用调用

卡片自动拉活的执行链路为：

```text
系统刷新调度
  → EntryFormAbility.onUpdateForm(formId)
  → formProvider.updateForm(formId, updateData)
  → 更新卡片的 widget_card_action
  → WidgetCard.onActionChange()
  → postCardAction({ action: 'call', abilityName: 'EntryAbility', ... })
  → EntryAbility 通过 call 启动
```

#### 1. 系统刷新触发更新回调

系统按定点刷新或周期刷新配置调用 `EntryFormAbility.onUpdateForm()`。下图展示系统的 `PostRefreshTask`、`NotifyFormUpdate` 日志，以及卡片提供方收到的 `onUpdateForm` 回调。

![系统刷新触发 EntryFormAbility.onUpdateForm](images/card_alive.png)

#### 2. 更新卡片数据，触发监听与 call 事件

`onUpdateForm()` 构造包含 `widget_card_action` 的数据，通过 `formProvider.updateForm(formId, updateData)` 推送到卡片。当前值包含更新时间，使后续刷新时该字段发生变化。

`WidgetCard` 使用以下绑定监听字段变化：

```typescript
@Watch('onActionChange')
@LocalStorageProp('widget_card_action')
action: string = '';
```

字段变化触发 `WidgetCard.onActionChange()`，随后调用：

```typescript
postCardAction(this, {
  action: 'call',
  abilityName: 'EntryAbility',
  params: {
    method: 'onUpdateForm',
    timestamp: Date.now()
  }
});
```

下图中的 `卡片action变化 action=onUpdateForm: 4:45:00 PM` 日志说明更新已传递到卡片，并触发监听方法。

![卡片数据更新触发 WidgetCard.onActionChange](images/card_alive_update.png)

#### 3. EntryAbility 受 call 启动

卡片发出的 `call` 事件请求启动 `EntryAbility`。下图展示其 `onCreate()` 日志，`launchReason=2` 与此次 call 启动相对应；结合上一张截图，可以观察到卡片字段变化后主应用被拉起的过程。

![EntryAbility 通过卡片 call 启动](images/card_alice_call_ability.png)

拉起 Ability 与执行指定业务方法是两个环节。当前代码已接入数据更新、字段监听和 `postCardAction`；`params.method` 指定的业务方法仍需通过 `callee.on()` 注册处理，不能仅凭 `onCreate()` 日志判断该业务方法已执行。

相关代码：

- `entry/src/main/resources/base/profile/form_config.json`：卡片更新配置，当前开启自动更新并配置每天 `16:45` 定点刷新。
- `entry/src/main/ets/entryformability/EntryFormAbility.ets`：接收系统更新回调，更新 `widget_card_action` 并推送卡片数据。
- `entry/src/main/ets/widget/pages/WidgetCard.ets`：监听字段变化并发送 `call` 事件。
- `entry/src/main/ets/entryability/EntryAbility.ets`：记录主应用启动与后台运行状态。

该方案属于按系统调度获得执行机会，不代表进程始终存活，也不能保证固定时间间隔的拉活。

## 2. 音频后台保活

应用进入后台时，`EntryAbility.onBackground()` 启动 `AudioPlayer`。播放器加载网络音乐，开启循环播放，并将音频输出设为静音：用户听不到声音，但播放器仍在执行播放任务。

### 配合进程缓存使用

音频后台保活可配合以下配置使用，在 `EntryAbility.onCreate()` 中启用进程缓存支持（当前工作区该行已注释，需要使用时取消注释）：

```typescript
this.context.getApplicationContext().setSupportedProcessCache(true);
```

本项目将该配置与后台静音循环播放、音频会话配合使用，目标是在后台持续运行，直到主动停止。进程缓存配置表达应用支持进程缓存，不等于获得永不被回收的保证；持续播放也不能保证在所有系统状态下无限期存活。

### 播放与后台任务

设计上通过以下能力配合维持后台运行：

1. `AVPlayer` 循环播放并静音，维持音频播放状态。
2. 创建并激活 `AVSession`，管理音频会话。
3. 申请 `AUDIO_PLAYBACK` 类型的长时后台任务，使后台执行与音频播放任务关联。

相关代码：

- `entry/src/main/ets/entryability/EntryAbility.ets`：进入后台时启动播放。
- `entry/src/main/ets/keepalive/AudioPlayer.ets`：静音循环播放、音频会话和长时后台任务方法。
- `entry/src/main/module.json5`：声明 `audioPlayback` 后台模式及相关权限。

**当前实现状态：** 静音循环播放和 `AVSession` 已接入；`startContinuousTask()` 虽然已定义，但没有被调用，因此尚未实际申请长时后台任务。当前使用的是普通网络音乐并静音输出，并非音频文件本身无声。

该方案主要用于维持已启动进程的后台运行，不能在进程被终止后自行重新拉起。实际效果需要在目标设备上验证，网络播放失败或系统回收都可能中断运行。

### 主动停止

可调用现有的停止接口，清除音频模块的存活日志定时器、停止并释放播放器，以及停用并销毁音频会话：

```typescript
await AudioPlayer.getInstance().stop(this.context);
```

目前 `EntryAbility.onDestroy()` 会调用该接口，页面尚未提供手动停止按钮。停止音频保活不会强制结束应用进程，`EntryAbility` 自身的日志定时器也会继续到其销毁时清理。若后续接入长时后台任务，还需在停止时配套取消该任务。

### 后台运行截图

![静音音频后台保活日志](images/audio_keep_alive.png)

截图中同时出现 `AudioPlayer` 的“进程存活验证”和 `EntryAbility` 的“当前处于 后台”日志，说明截图时应用已进入后台且仍在执行。截图未展示连续运行时长，因此不能据此推导“后台无限制存活不死”。

## 验证方式

添加桌面卡片、将应用切到后台，观察 `EntryFormAbility`、`EntryAbility` 和 `AudioPlayer` 的日志，分别确认卡片更新回调、音频播放状态以及后台任务是否成功启动。

代码中的“进程存活验证”定时日志只说明打印日志的时刻进程仍在执行，不具备拉活能力，也不能单独证明上述保活链路有效。
