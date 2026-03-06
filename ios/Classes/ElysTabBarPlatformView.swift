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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
}

/// Touch blocker view that intercepts touches and forwards to center button
@available(iOS 26.0, *)
class CenterTouchBlocker: UIView {
    var onTap: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestureRecognizer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestureRecognizer()
    }
    
    private func setupGestureRecognizer() {
        // Use gesture recognizer instead of touchesBegan/touchesEnded
        // This works better with Flutter's PlatformView touch handling
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        self.addGestureRecognizer(tap)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onTap?()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.point(inside: point, with: event) {
            return self
        }
        return nil
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

        // 用 tag 查找对应的 item，因为 items 数组中有额外的 spacer
        if let targetItem = items.first(where: { $0.tag == selectedIndex }) {
            bar.selectedItem = targetItem
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
        // iOS 26+: Use transparent background, let system handle Liquid Glass
        bar.isTranslucent = true
        bar.backgroundImage = UIImage()
        bar.shadowImage = UIImage()
        bar.backgroundColor = .clear
        
        // IMPORTANT: Do NOT set barTintColor on iOS 26+ as it interferes with Liquid Glass effect
        // barTintColor adds an opaque layer that makes the tab bar appear white/less transparent
        
        // Set theme color for selected items (#1F1F25)
        bar.tintColor = UIColor(red: 0x1F/255.0, green: 0x1F/255.0, blue: 0x25/255.0, alpha: 1.0)
    }

    private func buildItems(icons: [String], selectedIcons: [String], badgeCounts: [Int?]) -> [UITabBarItem] {
        var items: [UITabBarItem] = []

        for i in 0..<icons.count {
            let icon = icons[i]
            
            // Empty icon from Flutter = spacer position (for center button)
            if icon.isEmpty {
                let spacerImage = createSpacerImage(width: 40)
                let spacerItem = UITabBarItem(title: "", image: spacerImage, selectedImage: nil)
                spacerItem.tag = -999  // Special tag for spacer
                spacerItem.isEnabled = false
                items.append(spacerItem)
                continue
            }
            
            let selectedIcon = i < selectedIcons.count ? selectedIcons[i] : icon
            items.append(createTabItem(index: i, icon: icon, selectedIcon: selectedIcon, badgeCount: i < badgeCounts.count ? badgeCounts[i] : nil))
        }

        return items
    }

    private func createTabItem(index: Int, icon: String, selectedIcon: String, badgeCount: Int?) -> UITabBarItem {
        var image: UIImage?
        var selectedImage: UIImage?
        let iconSize = CGSize(width: 40, height: 40)
        let iconUseTemplate = shouldUseTemplateRendering(icon)
        let selectedIconUseTemplate = shouldUseTemplateRendering(selectedIcon)

        if !icon.isEmpty {
            // Try to load as animated image first (APNG/GIF)
            if let data = loadFlutterAssetData(icon) {
                image = loadImageFromData(
                    data,
                    size: iconSize,
                    asTemplate: iconUseTemplate
                )
            }
            // Fallback to static image
            if image == nil,
               let originalImage = loadFlutterAsset(
                    icon,
                    asTemplate: iconUseTemplate
               ) {
                image = resizeImage(
                    originalImage,
                    to: iconSize,
                    asTemplate: iconUseTemplate
                )
            }
        }

        if !selectedIcon.isEmpty {
            // Try animated first for selected icon too
            if let data = loadFlutterAssetData(selectedIcon) {
                selectedImage = loadImageFromData(
                    data,
                    size: iconSize,
                    asTemplate: selectedIconUseTemplate
                )
            }
            if selectedImage == nil,
               let originalImage = loadFlutterAsset(
                    selectedIcon,
                    asTemplate: selectedIconUseTemplate
               ) {
                selectedImage = resizeImage(
                    originalImage,
                    to: iconSize,
                    asTemplate: selectedIconUseTemplate
                )
            }
        }

        let item = UITabBarItem(title: "", image: image, selectedImage: selectedImage)
        item.tag = index

        if let count = badgeCount, count > 0 {
            item.badgeValue = count > 99 ? "99+" : String(count)
        }

        return item
    }

    private func resizeImage(_ image: UIImage, to size: CGSize, asTemplate: Bool = true) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        // Use template mode for better Liquid Glass effect on iOS 26+
        return resized.withRenderingMode(asTemplate ? .alwaysTemplate : .alwaysOriginal)
    }

    private func loadFlutterAsset(_ assetPath: String, asTemplate: Bool = true) -> UIImage? {
        let renderingMode: UIImage.RenderingMode = asTemplate ? .alwaysTemplate : .alwaysOriginal
        // Method 0: Local file path (absolute path / file:// / ~/)
        if let localPath = resolveLocalFilePath(assetPath) {
            return UIImage(contentsOfFile: localPath)?.withRenderingMode(renderingMode)
        }
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

    // MARK: - Animated Icon Support
    
    /// Load Flutter asset as Data (for checking animation)
    private func loadFlutterAssetData(_ assetPath: String) -> Data? {
        if let localPath = resolveLocalFilePath(assetPath) {
            return try? Data(contentsOf: URL(fileURLWithPath: localPath))
        }
        let key = registrar.lookupKey(forAsset: assetPath)
        if let path = Bundle.main.path(forResource: key, ofType: nil) {
            return try? Data(contentsOf: URL(fileURLWithPath: path))
        }
        let directPath = Bundle.main.bundleURL
            .appendingPathComponent("Frameworks/App.framework/flutter_assets")
            .appendingPathComponent(assetPath)
            .path
        if FileManager.default.fileExists(atPath: directPath) {
            return try? Data(contentsOf: URL(fileURLWithPath: directPath))
        }
        return nil
    }

    /// Resolve supported local paths:
    /// - absolute file path: /var/mobile/.../avatar.png
    /// - file URL: file:///var/mobile/.../avatar.png
    /// - home relative: ~/Library/.../avatar.png
    private func resolveLocalFilePath(_ rawPath: String) -> String? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // file:// URI
        if trimmed.hasPrefix("file://"),
           let url = URL(string: trimmed) {
            let filePath = url.path
            if FileManager.default.fileExists(atPath: filePath) {
                return filePath
            }
        }

        // absolute path
        if trimmed.hasPrefix("/"),
           FileManager.default.fileExists(atPath: trimmed) {
            return trimmed
        }

        // home relative path
        if trimmed.hasPrefix("~/") {
            let expandedPath = NSString(string: trimmed).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return expandedPath
            }
        }

        // percent-encoded local path
        if let decoded = trimmed.removingPercentEncoding,
           decoded != trimmed {
            if decoded.hasPrefix("file://"),
               let url = URL(string: decoded) {
                let filePath = url.path
                if FileManager.default.fileExists(atPath: filePath) {
                    return filePath
                }
            }

            if decoded.hasPrefix("/"),
               FileManager.default.fileExists(atPath: decoded) {
                return decoded
            }
        }

        return nil
    }

    /// Local user images should keep original color; bundled tab icons keep template rendering.
    private func shouldUseTemplateRendering(_ path: String) -> Bool {
        return resolveLocalFilePath(path) == nil
    }
    
    /// Check if image data contains animation (APNG/GIF)
    private func isAnimatedImage(data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }
        let frameCount = CGImageSourceGetCount(source)
        return frameCount > 1
    }
    
    /// Load image from data, supporting both static and animated images (APNG/GIF)
    /// Returns a UIImage that can be directly set on UITabBarItem.image
    private func loadImageFromData(_ data: Data, size: CGSize, asTemplate: Bool = true) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let frameCount = CGImageSourceGetCount(source)
        
        if frameCount <= 1 {
            // Static image
            if let image = UIImage(data: data) {
                return resizeImage(image, to: size, asTemplate: asTemplate)
            }
            return nil
        }
        
        // Animated image - extract frames and create UIImage.animatedImage
        var frames: [UIImage] = []
        var totalDuration: TimeInterval = 0
        
        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            
            let frameImage = UIImage(cgImage: cgImage)
            let resizedFrame = resizeImage(frameImage, to: size, asTemplate: asTemplate)
            frames.append(resizedFrame)
            
            // Get frame duration
            var frameDuration: TimeInterval = 0.1  // Default 100ms
            
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any] {
                // Try APNG duration
                if let pngProps = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
                    if let delay = pngProps[kCGImagePropertyAPNGDelayTime] as? TimeInterval {
                        frameDuration = delay
                    } else if let delay = pngProps[kCGImagePropertyAPNGUnclampedDelayTime] as? TimeInterval {
                        frameDuration = delay
                    }
                }
                // Try GIF duration
                else if let gifProps = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                    if let delay = gifProps[kCGImagePropertyGIFDelayTime] as? TimeInterval {
                        frameDuration = delay
                    } else if let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval {
                        frameDuration = delay
                    }
                }
            }
            
            // Ensure minimum duration
            if frameDuration < 0.01 {
                frameDuration = 0.1
            }
            totalDuration += frameDuration
        }
        
        guard !frames.isEmpty else { return nil }
        
        // Create animated UIImage - this can be set directly on UITabBarItem.image!
        return UIImage.animatedImage(with: frames, duration: totalDuration)
    }

    private func setupCenterButton(config: CenterButtonConfig) {
        guard let tabBar = tabBar else { return }

        // Touch blocker size (covers the entire center area to block tab selection)
        let blockerSize: CGFloat = 80  // Wider than button to ensure full coverage
        let imageSize: CGFloat = 44
        
        // Create touch blocker that sits on top of tab bar items
        // IMPORTANT: Add to container (not tabBar) to avoid Flutter PlatformView touch interception
        let blocker = CenterTouchBlocker()
        blocker.translatesAutoresizingMaskIntoConstraints = false
        blocker.backgroundColor = .clear  // Debug: change to .red.withAlphaComponent(0.3) to see area
        blocker.onTap = { [weak self] in
            self?.centerButtonTapped()
        }

        // Create center button (visual only, touch handled by blocker)
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isUserInteractionEnabled = false  // Disable - blocker handles touches

        // Load image from Flutter asset as original (not template) for center button
        // Center button keeps original colors since it's typically a colored icon
        if let originalImage = loadFlutterAsset(config.icon, asTemplate: false) {
            let resizedImage = resizeImage(originalImage, to: CGSize(width: imageSize, height: imageSize), asTemplate: false)
            button.setImage(resizedImage, for: .normal)
        }
        
        button.imageView?.contentMode = .center
        self.centerButton = button

        // Add to CONTAINER (not tabBar) - this is crucial for Flutter PlatformView touch handling
        // Flutter intercepts touches on tabBar subviews, but container is the root view we return
        container.addSubview(blocker)
        container.addSubview(button)
        
        // iOS 26 Liquid Glass tab bar has larger content area than traditional 49pt
        // Based on testing: tabBar height 83, safe area ~23, content area ~60
        // Center position = 60 / 2 = 30
        let buttonCenterY: CGFloat = 30
        
        NSLayoutConstraint.activate([
            // Touch blocker - positioned relative to tabBar but added to container
            blocker.centerXAnchor.constraint(equalTo: tabBar.centerXAnchor),
            blocker.topAnchor.constraint(equalTo: tabBar.topAnchor),
            blocker.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
            blocker.widthAnchor.constraint(equalToConstant: blockerSize),
            
            // Center button (visual) - centered in tab bar content area (excluding safe area)
            button.centerXAnchor.constraint(equalTo: tabBar.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: tabBar.topAnchor, constant: buttonCenterY),
            button.widthAnchor.constraint(equalToConstant: imageSize),
            button.heightAnchor.constraint(equalToConstant: imageSize)
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

                // 用 tag 查找对应的 item
                let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
                if let targetItem = items.first(where: { $0.tag == selectedIndex }) {
                    bar.selectedItem = targetItem
                    lastValidSelectedIndex = targetItem.tag
                }
            }
            result(nil)

        case "setSelectedIndex":
            guard let args = call.arguments as? [String: Any],
                  let idx = (args["index"] as? NSNumber)?.intValue else {
                result(FlutterError(code: "bad_args", message: "Invalid index", details: nil))
                return
            }

            // 用 tag 查找对应的 item，因为 items 数组中有额外的 spacer
            if let bar = tabBar, let items = bar.items,
               let targetItem = items.first(where: { $0.tag == idx }) {
                bar.selectedItem = targetItem
                lastValidSelectedIndex = targetItem.tag
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

            // 用 tag 来匹配 badgeCounts，因为 items 数组中有额外的 spacer
            if let bar = tabBar, let items = bar.items {
                for item in items {
                    let tag = item.tag
                    // 跳过 spacer (tag < 0)
                    guard tag >= 0, tag < badgeCounts.count else { continue }
                    
                    let count = badgeCounts[tag]
                    if let count = count, count > 0 {
                        item.badgeValue = count > 99 ? "99+" : String(count)
                    } else {
                        item.badgeValue = nil
                    }
                }
            }
            result(nil)

        case "updateItemIcon":
            guard let args = call.arguments as? [String: Any],
                  let index = (args["index"] as? NSNumber)?.intValue else {
                result(FlutterError(code: "bad_args", message: "Missing index", details: nil))
                return
            }

            let icon = args["icon"] as? String
            let selectedIcon = args["selectedIcon"] as? String
            let iconSize = CGSize(width: 40, height: 40)

            // Update stored icons
            if let icon = icon, index < self.currentIcons.count {
                self.currentIcons[index] = icon
            }
            if let selectedIcon = selectedIcon, index < self.currentSelectedIcons.count {
                self.currentSelectedIcons[index] = selectedIcon
            }

            // Find and update the item with matching tag
            if let bar = tabBar, let items = bar.items,
               let targetItem = items.first(where: { $0.tag == index }) {
                
                // Handle icon update - supports both static and animated (APNG/GIF)
                if let iconPath = icon, !iconPath.isEmpty {
                    let useTemplate = shouldUseTemplateRendering(iconPath)
                    if let data = loadFlutterAssetData(iconPath),
                       let loadedImage = loadImageFromData(
                            data,
                            size: iconSize,
                            asTemplate: useTemplate
                       ) {
                        targetItem.image = loadedImage
                    } else if let originalImage = loadFlutterAsset(
                        iconPath,
                        asTemplate: useTemplate
                    ) {
                        targetItem.image = resizeImage(
                            originalImage,
                            to: iconSize,
                            asTemplate: useTemplate
                        )
                    }
                }
                
                // Handle selected icon update - also supports animation
                if let selectedIconPath = selectedIcon, !selectedIconPath.isEmpty {
                    let useTemplate = shouldUseTemplateRendering(selectedIconPath)
                    if let data = loadFlutterAssetData(selectedIconPath),
                       let loadedImage = loadImageFromData(
                            data,
                            size: iconSize,
                            asTemplate: useTemplate
                       ) {
                        targetItem.selectedImage = loadedImage
                    } else if let originalImage = loadFlutterAsset(
                        selectedIconPath,
                        asTemplate: useTemplate
                    ) {
                        targetItem.selectedImage = resizeImage(
                            originalImage,
                            to: iconSize,
                            asTemplate: useTemplate
                        )
                    }
                }
            }
            result(nil)

        case "updateCenterButton":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "bad_args", message: "Missing args", details: nil))
                return
            }

            if let icon = args["icon"] as? String,
               let button = self.centerButton {
                let imageSize: CGFloat = 44
                if let originalImage = loadFlutterAsset(icon, asTemplate: false) {
                    let resizedImage = resizeImage(originalImage, to: CGSize(width: imageSize, height: imageSize), asTemplate: false)
                    button.setImage(resizedImage, for: .normal)
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
