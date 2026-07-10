import UIKit

@available(iOS 26.0, *)
final class ElysRightTabBarView: UIView, UITabBarDelegate {
    private let tabBar = UITabBar(frame: .zero)
    private let assetLoader: ElysAssetLoader
    private var tabs: [ElysTabConfig] = []
    private var configuredIconSize: CGFloat?
    var onSelect: ((ElysTabConfig, Int) -> Void)?

    init(assetLoader: ElysAssetLoader) {
        self.assetLoader = assetLoader
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // wipe 几何唯一入口（无 layoutSubviews 覆写，任何布局脉冲都不会改写
    // 内层几何）。wrapper 是裁剪窗口：progress 0→1 时窗口从自然 frame 线性
    // 收拢到 target（side 按钮矩形），内层 UITabBar 保持自然尺寸且屏幕定点
    // ——bounds/center/transform/alpha 全程零接触，只有可见窗口在变。
    // 所有值均为 progress 的线性函数且成对写入，additive 动画下「右缘/内容
    // 定点」不变量对任意曲线叠加与中断均成立；本函数幂等，动画块外的布局
    // 重放是模型 no-op。
    func applyWipe(natural: CGRect, target: CGRect, progress: CGFloat) {
        guard natural.width > 1, natural.height > 1 else { return }
        let p = min(max(progress, 0), 1)
        let width = max(0, natural.width + (target.width - natural.width) * p)
        let centerX = natural.midX + (target.midX - natural.midX) * p
        bounds = CGRect(origin: .zero, size: CGSize(width: width, height: natural.height))
        center = CGPoint(x: centerX, y: natural.midY)
        tabBar.bounds = CGRect(origin: .zero, size: natural.size)
        // 内层内容屏幕定点：tabCenterX(屏幕) ≡ natural.midX
        tabBar.center = CGPoint(
            x: natural.midX - (centerX - width / 2),
            y: natural.height / 2
        )
    }

    func configure(
        tabs: [ElysTabConfig],
        selectedId: String,
        iconSize: CGFloat,
        isDark: Bool
    ) {
        overrideUserInterfaceStyle = isDark ? .dark : .light
        // 整组替换 tabBar.items 会销毁重建所有 UITabBarButton，正在播放的
        // 选中动画会被掐断；Flutter 侧 setConfig 回写选中态时必须走复用路径。
        if let items = tabBar.items, canReuseItems(items, for: tabs, iconSize: iconSize) {
            for (index, item) in items.enumerated()
            where self.tabs[index].badgeCount != tabs[index].badgeCount {
                NativeTabBarBadgeStyle.setBadgeCount(tabs[index].badgeCount, on: item)
            }
            self.tabs = tabs
        } else {
            self.tabs = tabs
            configuredIconSize = iconSize
            tabBar.items = tabs.enumerated().map { index, tab in
                makeItem(for: tab, index: index, iconSize: iconSize)
            }
        }
        let items = tabBar.items ?? []
        let selected = items.first { item in
            tabs.indices.contains(item.tag) && tabs[item.tag].id == selectedId
        } ?? items.first
        if tabBar.selectedItem !== selected {
            tabBar.selectedItem = selected
        }
    }

    private func canReuseItems(
        _ items: [UITabBarItem],
        for newTabs: [ElysTabConfig],
        iconSize: CGFloat
    ) -> Bool {
        guard configuredIconSize == iconSize,
              items.count == newTabs.count,
              tabs.count == newTabs.count else { return false }
        // 可变本地文件（file:// 等）路径不变但内容可能已更新，复用会一直显示旧图。
        guard !newTabs.contains(where: { tab in
            ElysAssetLoader.isMutableLocalReference(tab.icon)
                || ElysAssetLoader.isMutableLocalReference(tab.selectedIcon ?? "")
        }) else { return false }
        return zip(tabs, newTabs).allSatisfy { old, new in
            old.id == new.id
                && old.icon == new.icon
                && old.selectedIcon == new.selectedIcon
                && old.accessibilityLabel == new.accessibilityLabel
        }
    }

    /// Programmatic selection update; assigning selectedItem does not fire
    /// the delegate, so no tabSelected event loops back to Dart.
    func setSelected(id: String) {
        guard let items = tabBar.items else { return }
        guard let item = items.first(where: { item in
            tabs.indices.contains(item.tag) && tabs[item.tag].id == id
        }) else { return }
        tabBar.selectedItem = item
    }

    func itemVisualCenterY() -> CGFloat? {
        tabBar.layoutIfNeeded()
        let itemViews = tabBar.subviews
            .filter { String(describing: type(of: $0)).contains("UITabBarButton") }
        guard !itemViews.isEmpty else { return nil }
        let total = itemViews.reduce(CGFloat(0)) { $0 + $1.center.y }
        return total / CGFloat(itemViews.count)
    }

    private func setup() {
        backgroundColor = .clear
        clipsToBounds = true
        tabBar.delegate = self
        tabBar.isTranslucent = true
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.backgroundColor = .clear
        tabBar.tintColor = .systemBlue
        addSubview(tabBar)
    }

    private func makeItem(for tab: ElysTabConfig, index: Int, iconSize: CGFloat) -> UITabBarItem {
        let size = CGSize(width: iconSize, height: iconSize)
        let image = assetLoader.image(named: tab.icon, size: size)
        let selectedIcon = tab.selectedIcon ?? tab.icon
        let selectedImage = assetLoader.image(named: selectedIcon, size: size)
        let item = UITabBarItem(title: "", image: image, selectedImage: selectedImage)
        item.tag = index
        item.accessibilityLabel = tab.accessibilityLabel ?? tab.id
        NativeTabBarBadgeStyle.setBadgeCount(tab.badgeCount, on: item)
        return item
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        let index = item.tag
        guard tabs.indices.contains(index) else { return }
        onSelect?(tabs[index], index)
    }
}
