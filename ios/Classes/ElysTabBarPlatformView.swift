import Flutter
import UIKit

/// Custom UITabBar that tracks touch location
@available(iOS 26.0, *)
class ElysCustomTabBar: UITabBar {
    var lastTouchLocation: CGPoint?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchLocation = touches.first?.location(in: self)
        super.touchesBegan(touches, with: event)
    }
}

/// Platform view for Elys Tab Bar with center button (iOS 15+)
@available(iOS 26.0, *)
class ElysTabBarPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {
    private let channel: FlutterMethodChannel
    private let container: UIView
    private let registrar: FlutterPluginRegistrar
    private var tabBar: ElysCustomTabBar?
    private var centerButton: UIButton?

    private var currentIcons: [String] = []
    private var currentSelectedIcons: [String] = []
    private var currentBadgeCounts: [Int?] = []
    private var centerButtonConfig: CenterButtonConfig?
    private var lastValidSelectedIndex: Int = 0

    struct CenterButtonConfig {
        let icon: String
        let backgroundColor: UIColor?
        let iconColor: UIColor?
    }

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar) {
        self.channel = FlutterMethodChannel(
            name: "elys_platform_ui/tab_bar_\(viewId)",
            binaryMessenger: messenger
        )
        self.container = UIView(frame: frame)
        self.registrar = registrar

        var icons: [String] = []
        var selectedIcons: [String] = []
        var badgeCounts: [Int?] = []
        var selectedIndex: Int = 0
        var isDark: Bool = false
        var backgroundColor: UIColor? = nil
        var centerButtonData: [String: Any]? = nil

        if let dict = args as? [String: Any] {
            icons = (dict["icons"] as? [String]) ?? []
            selectedIcons = (dict["selectedIcons"] as? [String]) ?? []
            if let badgeData = dict["badgeCounts"] as? [NSNumber?] {
                badgeCounts = badgeData.map { $0?.intValue }
            }
            if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
            if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
            if let n = dict["backgroundColor"] as? NSNumber { backgroundColor = Self.colorFromARGB(n.intValue) }
            centerButtonData = dict["centerButton"] as? [String: Any]
        }

        super.init()

        container.backgroundColor = .clear
        container.overrideUserInterfaceStyle = isDark ? .dark : .light

        // Parse center button config
        if let centerData = centerButtonData,
           let icon = centerData["icon"] as? String {
            var bgColor: UIColor? = nil
            var iconColor: UIColor? = nil
            if let n = centerData["backgroundColor"] as? NSNumber {
                bgColor = Self.colorFromARGB(n.intValue)
            }
            if let n = centerData["iconColor"] as? NSNumber {
                iconColor = Self.colorFromARGB(n.intValue)
            }
            self.centerButtonConfig = CenterButtonConfig(
                icon: icon,
                backgroundColor: bgColor,
                iconColor: iconColor
            )
        }

        // Create tab bar
        let bar = ElysCustomTabBar(frame: .zero)
        tabBar = bar
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.delegate = self  // Enable tab selection callback

        // Setup appearance
        setupTabBarAppearance(bar, backgroundColor: backgroundColor)

        // Build tab bar items
        let items = buildItems(icons: icons, selectedIcons: selectedIcons, badgeCounts: badgeCounts)
        bar.items = items

        if selectedIndex >= 0, selectedIndex < items.count {
            bar.selectedItem = items[selectedIndex]
        }

        container.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.topAnchor.constraint(equalTo: container.topAnchor),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.currentIcons = icons
        self.currentSelectedIcons = selectedIcons
        self.currentBadgeCounts = badgeCounts
        self.lastValidSelectedIndex = selectedIndex

        // Setup center button if configured
        if let config = self.centerButtonConfig {
            setupCenterButton(config: config)
        }

        // Setup method call handler
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }
            self.handleMethodCall(call, result: result)
        }
    }

    private func setupTabBarAppearance(_ bar: UITabBar, backgroundColor: UIColor?) {
        let appearance = UITabBarAppearance()

        // Glass effect
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        appearance.shadowColor = .clear

        // Hide title
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]

        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance

        if let bg = backgroundColor {
            bar.barTintColor = bg
        }
    }

    private func buildItems(icons: [String], selectedIcons: [String], badgeCounts: [Int?]) -> [UITabBarItem] {
        var items: [UITabBarItem] = []

        // Calculate split point
        let splitIndex = (icons.count + 1) / 2

        // Add left-side items
        for i in 0..<min(splitIndex, icons.count) {
            let selectedIcon = i < selectedIcons.count ? selectedIcons[i] : icons[i]
            items.append(createTabItem(index: i, icon: icons[i], selectedIcon: selectedIcon, badgeCount: i < badgeCounts.count ? badgeCounts[i] : nil))
        }

        // Add center spacer with transparent image (80pt wide for center button + padding)
        let spacerImage = createSpacerImage(width: 80)
        let spacerItem = UITabBarItem(title: "", image: spacerImage, selectedImage: nil)
        spacerItem.tag = -999  // Special tag for spacer
        spacerItem.isEnabled = false  // Disable selection for spacer
        items.append(spacerItem)

        // Add right-side items
        for i in splitIndex..<icons.count {
            let selectedIcon = i < selectedIcons.count ? selectedIcons[i] : icons[i]
            items.append(createTabItem(index: i, icon: icons[i], selectedIcon: selectedIcon, badgeCount: i < badgeCounts.count ? badgeCounts[i] : nil))
        }

        return items
    }

    private func createTabItem(index: Int, icon: String, selectedIcon: String, badgeCount: Int?) -> UITabBarItem {
        var image: UIImage?
        var selectedImage: UIImage?

        if !icon.isEmpty {
            if let originalImage = loadFlutterAsset(icon) {
                image = resizeImage(originalImage, to: CGSize(width: 26, height: 26))
            }
        }

        if !selectedIcon.isEmpty {
            if let originalImage = loadFlutterAsset(selectedIcon) {
                selectedImage = resizeImage(originalImage, to: CGSize(width: 26, height: 26))
            }
        }

        let item = UITabBarItem(title: "", image: image, selectedImage: selectedImage)
        item.tag = index

        if let count = badgeCount, count > 0 {
            item.badgeValue = count > 99 ? "99+" : String(count)
        }

        return item
    }

    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resized.withRenderingMode(.alwaysOriginal)
    }

    private func loadFlutterAsset(_ assetPath: String, asTemplate: Bool = true) -> UIImage? {
        let renderingMode: UIImage.RenderingMode = asTemplate ? .alwaysTemplate : .alwaysOriginal
        // Method 1: Use registrar lookup
        let key = registrar.lookupKey(forAsset: assetPath)
        if let path = Bundle.main.path(forResource: key, ofType: nil) {
            return UIImage(contentsOfFile: path)?.withRenderingMode(renderingMode)
        }
        // Method 2: Direct path to flutter_assets
        let directPath = Bundle.main.bundleURL
            .appendingPathComponent("Frameworks/App.framework/flutter_assets")
            .appendingPathComponent(assetPath)
            .path
        if FileManager.default.fileExists(atPath: directPath) {
            return UIImage(contentsOfFile: directPath)?.withRenderingMode(renderingMode)
        }
        return nil
    }

    /// Create a transparent spacer image with specified width
    private func createSpacerImage(width: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.clear.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        // Use alwaysTemplate so it can be tinted to clear
        return image.withRenderingMode(.alwaysOriginal)
    }

    private func setupCenterButton(config: CenterButtonConfig) {
        guard let tabBar = tabBar else { return }

        // Create touch blocking view (covers spacer area, blocks touches from reaching tabBar)
        let touchBlocker = UIView()
        touchBlocker.translatesAutoresizingMaskIntoConstraints = false
        touchBlocker.backgroundColor = .clear
        touchBlocker.isUserInteractionEnabled = true  // Intercept touches
        tabBar.addSubview(touchBlocker)

        // Create center button (no external styling, just the image)
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Load image from Flutter asset as original (not template) and resize to 40x40
        if let originalImage = loadFlutterAsset(config.icon, asTemplate: false) {
            let resizedImage = resizeImage(originalImage, to: CGSize(width: 40, height: 40))
            button.setImage(resizedImage, for: .normal)
        }

        button.addTarget(self, action: #selector(centerButtonTapped), for: .touchUpInside)

        // Add to tabBar, positioned at center
        tabBar.addSubview(button)
        self.centerButton = button

        // Touch blocker and button
        let blockerSize: CGFloat = 48
        let buttonSize: CGFloat = 40
        
        // Use centerY with adjustable offset (positive = move down)
        let verticalOffset: CGFloat = 6  // Adjust this value if needed
        
        NSLayoutConstraint.activate([
            // Touch blocker
            touchBlocker.centerXAnchor.constraint(equalTo: tabBar.centerXAnchor),
            touchBlocker.centerYAnchor.constraint(equalTo: tabBar.topAnchor, constant: 25 + verticalOffset),
            touchBlocker.widthAnchor.constraint(equalToConstant: blockerSize),
            touchBlocker.heightAnchor.constraint(equalToConstant: blockerSize),

            // Center button
            button.centerXAnchor.constraint(equalTo: tabBar.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: tabBar.topAnchor, constant: 25 + verticalOffset),
            button.widthAnchor.constraint(equalToConstant: buttonSize),
            button.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
    }

    @objc private func centerButtonTapped() {
        channel.invokeMethod("onCenterButtonPressed", arguments: nil)

        // Animation feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.centerButton?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.centerButton?.transform = .identity
            }
        }
    }

    // MARK: - UITabBarDelegate

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        // If spacer is selected, determine direction based on touch location
        if item.tag == -999 {
            // Use async to ensure restoration happens after UITabBar's internal state update
            DispatchQueue.main.async { [weak self] in
                guard let self = self,
                      let bar = self.tabBar,
                      let items = bar.items else { return }
                
                // Find spacer index in items array
                guard let spacerIndex = items.firstIndex(where: { $0.tag == -999 }) else { return }
                
                // Determine target based on touch location
                var targetItem: UITabBarItem?
                
                if let touchLocation = bar.lastTouchLocation {
                    let centerX = bar.bounds.width / 2
                    
                    if touchLocation.x < centerX {
                        // Touch was on left side - select rightmost item before spacer
                        for i in stride(from: spacerIndex - 1, through: 0, by: -1) {
                            if items[i].tag >= 0 {
                                targetItem = items[i]
                                break
                            }
                        }
                    } else {
                        // Touch was on right side - select leftmost item after spacer
                        for i in (spacerIndex + 1)..<items.count {
                            if items[i].tag >= 0 {
                                targetItem = items[i]
                                break
                            }
                        }
                    }
                    bar.lastTouchLocation = nil
                }
                
                // Fallback to previous selection if no target found
                if targetItem == nil {
                    targetItem = items.first(where: { $0.tag == self.lastValidSelectedIndex })
                }
                
                if let target = targetItem {
                    bar.selectedItem = target
                    self.lastValidSelectedIndex = target.tag
                    self.channel.invokeMethod("valueChanged", arguments: ["index": target.tag])
                }
            }
            return
        }
        
        lastValidSelectedIndex = item.tag
        channel.invokeMethod("valueChanged", arguments: ["index": item.tag])
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getIntrinsicSize":
            let tabBarHeight = (tabBar?.sizeThatFits(.zero).height ?? 50)
            result(["width": Double(container.bounds.width), "height": Double(tabBarHeight)])

        case "setItems":
            guard let args = call.arguments as? [String: Any],
                  let icons = args["icons"] as? [String] else {
                result(FlutterError(code: "bad_args", message: "Missing items", details: nil))
                return
            }

            let selectedIcons = (args["selectedIcons"] as? [String]) ?? []
            var badgeCounts: [Int?] = []
            if let badgeData = args["badgeCounts"] as? [NSNumber?] {
                badgeCounts = badgeData.map { $0?.intValue }
            }

            self.currentIcons = icons
            self.currentSelectedIcons = selectedIcons
            self.currentBadgeCounts = badgeCounts

            if let bar = tabBar {
                let items = buildItems(icons: icons, selectedIcons: selectedIcons, badgeCounts: badgeCounts)
                bar.items = items

                let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
                if selectedIndex >= 0, selectedIndex < items.count, items[selectedIndex].tag >= 0 {
                    bar.selectedItem = items[selectedIndex]
                    lastValidSelectedIndex = selectedIndex
                }
            }
            result(nil)

        case "setSelectedIndex":
            guard let args = call.arguments as? [String: Any],
                  let idx = (args["index"] as? NSNumber)?.intValue else {
                result(FlutterError(code: "bad_args", message: "Invalid index", details: nil))
                return
            }

            if let bar = tabBar, let items = bar.items, idx >= 0, idx < items.count, items[idx].tag >= 0 {
                bar.selectedItem = items[idx]
                lastValidSelectedIndex = idx
            }
            result(nil)

        case "setBadgeCounts":
            guard let args = call.arguments as? [String: Any],
                  let badgeData = args["badgeCounts"] as? [NSNumber?] else {
                result(FlutterError(code: "bad_args", message: "Missing badge counts", details: nil))
                return
            }

            let badgeCounts = badgeData.map { $0?.intValue }
            self.currentBadgeCounts = badgeCounts

            if let bar = tabBar, let items = bar.items {
                for (index, item) in items.enumerated() {
                    if index < badgeCounts.count {
                        let count = badgeCounts[index]
                        if let count = count, count > 0 {
                            item.badgeValue = count > 99 ? "99+" : String(count)
                        } else {
                            item.badgeValue = nil
                        }
                    }
                }
            }
            result(nil)

        case "setStyle":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "bad_args", message: "Missing style", details: nil))
                return
            }

            var bg: UIColor? = nil
            if let n = args["backgroundColor"] as? NSNumber {
                bg = Self.colorFromARGB(n.intValue)
            }

            if let bar = tabBar {
                setupTabBarAppearance(bar, backgroundColor: bg)
            }
            result(nil)

        case "setBrightness":
            guard let args = call.arguments as? [String: Any],
                  let isDark = (args["isDark"] as? NSNumber)?.boolValue else {
                result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
                return
            }

            container.overrideUserInterfaceStyle = isDark ? .dark : .light
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func view() -> UIView { container }

    private static func colorFromARGB(_ argb: Int) -> UIColor {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

/// Factory for creating ElysTabBarPlatformView instances
@available(iOS 26.0, *)
class ElysTabBarViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private let registrar: FlutterPluginRegistrar

    init(messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar) {
        self.messenger = messenger
        self.registrar = registrar
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return ElysTabBarPlatformView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger,
            registrar: registrar
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
