import Flutter
import UIKit

/// Manager for Elys Native Tab Bar with Center Floating Action Button
/// This class manages a native UITabBarController with a floating center button
@available(iOS 26.0, *)
class ElysNativeTabBarManager: NSObject {

    static let shared = ElysNativeTabBarManager()

    private var tabBarController: ElysTabBarController?
    private var flutterViewController: FlutterViewController?
    private var methodChannel: FlutterMethodChannel?

    private var tabConfigurations: [TabConfig] = []
    private var centerButtonConfig: CenterButtonConfig?
    private var isEnabled: Bool = false

    struct TabConfig {
        let title: String
        let sfSymbol: String?
        let badgeCount: Int?
    }

    struct CenterButtonConfig {
        let sfSymbol: String
        let backgroundColor: Int? // ARGB color
        let iconColor: Int? // ARGB color
    }

    private override init() {
        super.init()
    }

    /// Setup native tab bar with Flutter
    func setup(messenger: FlutterBinaryMessenger) {
        // Setup method channel
        self.methodChannel = FlutterMethodChannel(
            name: "elys_platform_ui/native_tab_bar",
            binaryMessenger: messenger
        )

        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    /// Find Flutter view controller
    private func getFlutterViewController() -> FlutterViewController? {
        if let flutterVC = flutterViewController {
            return flutterVC
        }

        // Try to find it from windows
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {

            if let flutterVC = window.rootViewController as? FlutterViewController {
                self.flutterViewController = flutterVC
                return flutterVC
            }
        }

        return nil
    }

    /// Enable native tab bar mode
    private func enableNativeTabBar(tabs: [TabConfig], centerButton: CenterButtonConfig?, selectedIndex: Int) {
        guard let flutterVC = getFlutterViewController() else {
            return
        }

        // Create tab bar controller if needed
        if tabBarController == nil {
            let tabBar = ElysTabBarController()
            tabBar.centerButtonDelegate = self
            tabBarController = tabBar

            // Setup appearance
            setupTabBarAppearance(tabBar)
        }

        guard let tabBar = tabBarController else { return }

        // Store configuration
        self.tabConfigurations = tabs
        self.centerButtonConfig = centerButton

        // Create view controllers for each tab
        var viewControllers: [UIViewController] = []

        for (index, config) in tabs.enumerated() {
            // Regular tab - use Flutter view
            let tabVC = FlutterTabViewController()
            tabVC.tabIndex = index
            tabVC.onTabSelected = { [weak self] idx in
                self?.notifyTabSelected(idx)
            }

            // Setup tab bar item
            var image: UIImage?
            if let symbol = config.sfSymbol {
                image = UIImage(systemName: symbol)
            }
            tabVC.tabBarItem = UITabBarItem(
                title: config.title,
                image: image,
                selectedImage: image
            )
            tabVC.tabBarItem.tag = index

            NativeTabBarBadgeStyle.setBadgeCount(
                config.badgeCount,
                on: tabVC.tabBarItem
            )

            viewControllers.append(tabVC)
        }

        tabBar.viewControllers = viewControllers
        tabBar.selectedIndex = selectedIndex
        tabBar.delegate = self

        // Setup center button if provided
        if let centerButton = centerButton {
            tabBar.setupCenterButton(
                sfSymbol: centerButton.sfSymbol,
                backgroundColor: argbToUIColor(centerButton.backgroundColor),
                iconColor: argbToUIColor(centerButton.iconColor)
            )
        } else {
            tabBar.removeCenterButton()
        }

        // Replace root view controller
        if let window = flutterVC.view.window {
            // Embed Flutter view in the selected tab
            if selectedIndex < viewControllers.count,
               let selectedTab = viewControllers[selectedIndex] as? FlutterTabViewController {
                selectedTab.embedFlutterView(flutterVC.view)
            }

            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                window.rootViewController = tabBar
            }

            self.isEnabled = true
        }
    }

    /// Disable native tab bar and return to Flutter-only mode
    private func disableNativeTabBar() {
        guard let flutterVC = getFlutterViewController(),
              let window = flutterVC.view.window else {
            return
        }

        // Remove Flutter view from tab if embedded
        if let tabBar = tabBarController,
           let selectedVC = tabBar.selectedViewController as? FlutterTabViewController {
            selectedVC.removeFlutterView()
        }

        // Restore Flutter as root
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = flutterVC
        }

        self.isEnabled = false
        self.tabBarController = nil
    }

    private func setupTabBarAppearance(_ tabBar: ElysTabBarController) {
        let appearance = UITabBarAppearance()

        // Modern glass design
        appearance.configureWithDefaultBackground()

        // Enable blur for glass effect
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        appearance.shadowColor = .clear

        tabBar.tabBar.standardAppearance = appearance
        tabBar.tabBar.scrollEdgeAppearance = appearance
    }

    private func notifyTabSelected(_ index: Int) {
        methodChannel?.invokeMethod("onTabSelected", arguments: ["index": index])

        // Move Flutter view to selected tab
        if let flutterView = getFlutterViewController()?.view,
           let tabBar = tabBarController,
           let selectedVC = tabBar.selectedViewController as? FlutterTabViewController {
            selectedVC.embedFlutterView(flutterView)
        }
    }

    private func notifyCenterButtonPressed() {
        methodChannel?.invokeMethod("onCenterButtonPressed", arguments: nil)
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "enableNativeTabBar":
            guard let args = call.arguments as? [String: Any],
                  let tabsData = args["tabs"] as? [[String: Any]] else {
                result(FlutterError(code: "invalid_args", message: "Invalid tabs data", details: nil))
                return
            }

            let tabs = tabsData.compactMap { data -> TabConfig? in
                guard let title = data["title"] as? String else { return nil }
                let symbol = data["sfSymbol"] as? String
                let badgeCount = data["badgeCount"] as? Int
                return TabConfig(title: title, sfSymbol: symbol, badgeCount: badgeCount)
            }

            // Parse center button config
            var centerButton: CenterButtonConfig?
            if let centerButtonData = args["centerButton"] as? [String: Any] {
                if let sfSymbol = centerButtonData["sfSymbol"] as? String {
                    centerButton = CenterButtonConfig(
                        sfSymbol: sfSymbol,
                        backgroundColor: centerButtonData["backgroundColor"] as? Int,
                        iconColor: centerButtonData["iconColor"] as? Int
                    )
                }
            }

            let selectedIndex = (args["selectedIndex"] as? Int) ?? 0
            enableNativeTabBar(tabs: tabs, centerButton: centerButton, selectedIndex: selectedIndex)
            result(nil)

        case "disableNativeTabBar":
            disableNativeTabBar()
            result(nil)

        case "setSelectedIndex":
            guard let args = call.arguments as? [String: Any],
                  let index = args["index"] as? Int else {
                result(FlutterError(code: "invalid_args", message: "Invalid index", details: nil))
                return
            }
            tabBarController?.selectedIndex = index
            result(nil)

        case "isEnabled":
            result(isEnabled)

        case "setBadgeCounts":
            guard let args = call.arguments as? [String: Any],
                  let badgeCounts = args["badgeCounts"] as? [Int?] else {
                result(FlutterError(code: "invalid_args", message: "Invalid badge counts", details: nil))
                return
            }

            // Update badge counts for existing tab bar items
            if let tabBar = tabBarController, let viewControllers = tabBar.viewControllers {
                for (index, viewController) in viewControllers.enumerated() {
                    if index < badgeCounts.count {
                        let count = badgeCounts[index]
                        NativeTabBarBadgeStyle.setBadgeCount(
                            count,
                            on: viewController.tabBarItem
                        )
                    }
                }
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Helper: Convert ARGB to UIColor
    private func argbToUIColor(_ argb: Int?) -> UIColor? {
        guard let argb = argb else { return nil }
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - UITabBarControllerDelegate

@available(iOS 26.0, *)
extension ElysNativeTabBarManager: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let index = tabBarController.viewControllers?.firstIndex(of: viewController) ?? 0
        notifyTabSelected(index)
    }
}

// MARK: - ElysTabBarControllerCenterButtonDelegate

@available(iOS 26.0, *)
extension ElysNativeTabBarManager: ElysTabBarControllerCenterButtonDelegate {
    func centerButtonPressed(in tabBar: ElysTabBarController) {
        notifyCenterButtonPressed()
    }
}

// MARK: - ElysTabBarController (Custom Tab Bar with Center Button)

@available(iOS 15.0, *)
class ElysTabBarController: UITabBarController {

    weak var centerButtonDelegate: ElysTabBarControllerCenterButtonDelegate?
    private var centerButton: UIButton?
    private var centerButtonContainer: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutCenterButton()
    }

    func setupCenterButton(sfSymbol: String, backgroundColor: UIColor?, iconColor: UIColor?) {
        // Create container for the button (to handle positioning above tab bar)
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Create the center button
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false

        // Set icon
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let image = UIImage(systemName: sfSymbol, withConfiguration: config)
        button.setImage(image, for: .normal)

        // Set tintColor
        button.tintColor = iconColor ?? .white

        // Set background
        let bg_color = backgroundColor ?? UIColor.systemBlue
        button.backgroundColor = bg_color

        // Make circular
        button.layer.cornerRadius = 28
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.2

        button.addTarget(self, action: #selector(centerButtonTapped), for: .touchUpInside)

        container.addSubview(button)
        self.view.addSubview(container)

        // Store references
        self.centerButton = button
        self.centerButtonContainer = container

        // Setup constraints
        NSLayoutConstraint.activate([
            // Container constraints (bottom of view, center horizontally)
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.heightAnchor.constraint(equalTo: tabBar.heightAnchor),

            // Button constraints (center in container, floating above)
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            button.widthAnchor.constraint(equalToConstant: 56),
            button.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    func removeCenterButton() {
        centerButton?.removeFromSuperview()
        centerButton = nil
        centerButtonContainer?.removeFromSuperview()
        centerButtonContainer = nil
    }

    private func layoutCenterButton() {
        // Additional layout adjustments if needed
    }

    @objc private func centerButtonTapped() {
        centerButtonDelegate?.centerButtonPressed(in: self)

        // Add animation feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.centerButton?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.centerButton?.transform = .identity
            }
        }
    }
}

// MARK: - Center Button Delegate Protocol

protocol ElysTabBarControllerCenterButtonDelegate: AnyObject {
    @available(iOS 15.0, *)
    func centerButtonPressed(in tabBar: ElysTabBarController)
}

// MARK: - Flutter Tab View Controller

private class FlutterTabViewController: UIViewController {
    var tabIndex: Int = 0
    var onTabSelected: ((Int) -> Void)?
    private var embeddedFlutterView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onTabSelected?(tabIndex)
    }

    func embedFlutterView(_ flutterView: UIView) {
        // Remove from previous parent
        flutterView.removeFromSuperview()

        // Add to this view controller
        flutterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flutterView)
        NSLayoutConstraint.activate([
            flutterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            flutterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            flutterView.topAnchor.constraint(equalTo: view.topAnchor),
            flutterView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        embeddedFlutterView = flutterView
    }

    func removeFlutterView() {
        embeddedFlutterView?.removeFromSuperview()
        embeddedFlutterView = nil
    }
}

// MARK: - UITabBarControllerDelegate (Internal)

@available(iOS 15.0, *)
extension ElysTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // Delegate is handled by ElysNativeTabBarManager
    }
}
