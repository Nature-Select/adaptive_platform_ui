import UIKit

@available(iOS 26.0, *)
final class ElysRightTabBarView: UIView, UITabBarDelegate {
    private let tabBar = UITabBar(frame: .zero)
    private let assetLoader: ElysAssetLoader
    private var tabs: [ElysTabConfig] = []
    var onSelect: ((ElysTabConfig, Int) -> Void)?

    init(assetLoader: ElysAssetLoader) {
        self.assetLoader = assetLoader
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        tabBar.frame = bounds
    }

    func configure(
        tabs: [ElysTabConfig],
        selectedId: String,
        iconSize: CGFloat,
        isDark: Bool
    ) {
        self.tabs = tabs
        overrideUserInterfaceStyle = isDark ? .dark : .light
        let items = tabs.enumerated().map { index, tab in
            makeItem(for: tab, index: index, iconSize: iconSize)
        }
        tabBar.items = items
        tabBar.selectedItem = items.first { item in
            tabs.indices.contains(item.tag) && tabs[item.tag].id == selectedId
        } ?? items.first
    }

    func itemVisualCenterY() -> CGFloat? {
        layoutIfNeeded()
        tabBar.layoutIfNeeded()
        let itemViews = tabBar.subviews
            .filter { String(describing: type(of: $0)).contains("UITabBarButton") }
        guard !itemViews.isEmpty else { return nil }
        let total = itemViews.reduce(CGFloat(0)) { $0 + $1.center.y }
        return total / CGFloat(itemViews.count)
    }

    private func setup() {
        backgroundColor = .clear
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
