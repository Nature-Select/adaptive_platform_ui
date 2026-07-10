# QA 功能说明: Elys 底栏切换性能修复

## 功能标识

- 功能域: `elys-tab-bar`
- 功能点: `tab-switch-performance`
- 最近更新: feat/elys-bar-perf-set-bar-hidden

## 背景

实际项目中点击 Elys 底栏 tab 出现掉帧和选中动画闪断。根因：每次选中态从 Flutter 回写原生时，包内全量重建 UITabBarItem 并从磁盘无缓存重载全部图标（每次切换约 16 次磁盘 IO，且执行两遍），全部发生在主线程并掐断 UIKit 正在播放的液态玻璃选中动画。

## 用户故事

作为 Elys App 用户，我希望点击底栏 tab 时选中动画完整流畅、页面切换不掉帧。

## 变更范围

- 优化行为：图标解码结果缓存（NSCache）；tabs 内容未变时复用 UITabBarItem（badge 就地更新）；图标配置只在配置或尺寸真正变化时执行
- 不在本 PR 范围：业务 App 侧页面切换本身的构建开销（IndexedStack 保活等属业务侧优化）

## 本次变更

无新增用户可见功能，属性能修复；用户可感知变化：

- tab 选中动画不再被打断/闪跳
- 切换 tab、弹出键盘、输入形态切换期间掉帧显著减少

## 当前确认行为

- badge 数量变化仍即时生效（就地更新路径）
- tabs 图标/顺序/无障碍标签变化仍触发完整重建（与旧行为一致）
- 深浅色切换、动态图片（file:// 路径头像等）不受缓存影响——可变本地文件明确排除在缓存外

## 验收标准

- 前置 4 个 tab 正常配置，当快速连续切换 tab，则选中动画每次完整播放、无闪断，帧率无肉眼可见卡顿
- 前置消息 tab 有 badge，当 badge 数变化，则数字即时更新且不打断任何动画
- 前置输入框激活，当键盘弹出/收起，则动画期间无卡顿
- 当业务侧更换某 tab 图标资源路径，则新图标正确显示（缓存不串图）

## 测试关注点

- 正向用例：各 tab 往返切换、badge 增减、深浅色切换后图标正确
- 边界用例：动画播放中再次点击其他 tab；输入 prefix 使用 file:// 动态图片时多次进出输入态（验证不被缓存旧图）
- 回归范围：底栏全部既有交互（tab 选中、leading 按钮、输入形态切换、键盘跟随、选项弹层）
- 性能验证（真机）：Instruments Time Profiler 中点击 tab 不应再出现 `ElysAssetLoader.loadImage` 火焰；Flutter DevTools timeline 切换帧 raster 段明显缩短

## 变更历史

- feat/elys-bar-perf-set-bar-hidden: 图标缓存 + item 复用 + 配置代际门控
