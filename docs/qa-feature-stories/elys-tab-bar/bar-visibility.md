# QA 功能说明: Elys 底栏原生显隐（setBarHidden）

## 功能标识

- 功能域: `elys-tab-bar`
- 功能点: `bar-visibility`
- 最近更新: feat/elys-bar-perf-set-bar-hidden

## 背景

业务侧（Elys App）需要在滚动、沉浸态等场景隐藏底栏。此前只能在 Flutter 侧用尺寸动画（SizeTransition）包裹组件，会逐帧 resize 平台视图并触发布局连锁导致掉帧。本次在包内新增原生侧显隐动画。

## 用户故事

作为 Elys App 开发者，我希望调用 `controller.setBarHidden(true/false)` 让底栏以原生动画平滑滑出/滑回屏幕底部，以便实现不掉帧的沉浸式体验。

## 变更范围

- 新增行为：`ElysNativeTabBarController.setBarHidden(bool hidden, {bool animated = true})`；原生 method channel 方法 `setBarHidden`
- 不在本 PR 范围：隐藏状态在平台视图重建后的自动恢复（见「未确认事项」）

## 本次变更

- 隐藏：整条 bar（leading 按钮 + tab 组 + 收起态输入框）以 UIView spring 动画（约 0.32s，无过冲）整体下移出屏；动画完成后 bar 区域点击穿透给 Flutter 页面内容
- 显示：反向动画滑回原位，交互恢复
- 隐藏时若输入态激活，先收起键盘（等效点击空白处 blur）
- `animated: false` 时立即生效无动画
- 平台视图尺寸全程不变，Flutter 侧布局零变化

## 触发入口

- API：`ElysNativeTabBarController.setBarHidden`
- Demo：example「Elys Tab Bar Platform View」页右上角「隐藏底栏/显示底栏」按钮

## 主流程

1. 业务调用 `setBarHidden(true)`
2. 底栏整体平滑下移出屏（选中态、badge 等状态保留）
3. 隐藏期间点击原 bar 区域，事件到达 Flutter 页面内容
4. 业务调用 `setBarHidden(false)`，底栏滑回，tab 点击恢复正常

## 分支与异常流程

- 隐藏动画进行中立即调显示：动画从当前位置平滑折返，无闪烁（代际守卫防止旧动画回调误置隐藏）
- 输入态激活时隐藏：键盘先收起，随后 bar 滑出
- 重复调用同一状态：no-op
- 平台视图尚未创建时调用：静默 no-op（与 controller 其他方法一致）

## 验收标准

- 前置底栏可见，当调用 `setBarHidden(true)`，则底栏 ~0.3s 内平滑滑出屏幕，无闪烁、无页面布局跳动
- 前置底栏已隐藏，当点击原底栏区域，则页面内容响应点击（穿透生效）
- 前置底栏已隐藏，当调用 `setBarHidden(false)`，则底栏滑回且 tab 可正常切换、选中态与 badge 与隐藏前一致
- 前置输入框激活且键盘弹出，当调用 `setBarHidden(true)`，则键盘收起且 bar 滑出

## 数据与接口影响

- 新增 method channel 方法 `setBarHidden {hidden, animated}`，向后兼容；本次未改动埋点

## 测试关注点

- 正向用例：显隐往返 × 有/无动画 × 各 tab 选中态
- 边界用例：动画中途反向切换连点；输入态/键盘弹出时隐藏；隐藏期间切换深浅色模式后再显示
- 异常/失败用例：隐藏期间调用 `focusInput`（已知会激活不可见输入，业务侧应避免）
- 回归范围：tab 切换、输入形态切换、键盘跟随（隐藏功能不应影响既有路径）

## 未确认事项

- 平台视图被 Flutter 销毁重建后（如页面级重建），原生隐藏状态会重置为可见而业务侧可能仍认为隐藏；业务侧需在重建后重新调用 `setBarHidden`（follow-up 计划将该状态纳入 config 同步）

## 变更历史

- feat/elys-bar-perf-set-bar-hidden: 新增原生显隐动画 API
