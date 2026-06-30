import UIKit

@available(iOS 26.0, *)
final class ElysInputOptionPresenter: NSObject, UIPopoverPresentationControllerDelegate {
    private let assetLoader: ElysAssetLoader
    private var items: [ElysInputOptionConfig] = []
    private weak var currentViewController: ElysOptionPopoverViewController?
    private var tapDismissView: UIControl?
    private var isPresented = false
    var onPresentationChanged: ((Bool) -> Void)?

    init(assetLoader: ElysAssetLoader) {
        self.assetLoader = assetLoader
        super.init()
    }

    var hasItems: Bool {
        !items.isEmpty
    }

    func configure(items: [ElysInputOptionConfig]) {
        self.items = items
        currentViewController?.update(items: items)
    }

    func update(item: ElysInputOptionConfig) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        currentViewController?.update(items: items)
    }

    func present(
        from sourceView: UIView,
        in containerView: UIView,
        onSelect: @escaping (ElysInputOptionConfig) -> Void
    ) {
        guard hasItems,
              let presenter = topViewController(from: containerView) else { return }
        dismissCurrent(animated: false)

        let viewController = ElysOptionPopoverViewController(
            items: items,
            assetLoader: assetLoader
        ) { [weak self] item in
            self?.dismissCurrent(animated: true)
            onSelect(item)
        }
        viewController.modalPresentationStyle = .popover
        viewController.popoverPresentationController?.sourceItem = sourceView
        viewController.popoverPresentationController?.sourceRect = sourceView.bounds
        viewController.popoverPresentationController?.permittedArrowDirections = []
        viewController.popoverPresentationController?.backgroundColor = .clear
        viewController.popoverPresentationController?.delegate = self
        currentViewController = viewController
        installTapDismissView(in: containerView.window ?? presenter.view.window)
        setPresented(true)
        presenter.present(viewController, animated: true)
    }

    func dismiss(animated: Bool) {
        dismissCurrent(animated: animated)
    }

    func adaptivePresentationStyle(
        for controller: UIPresentationController
    ) -> UIModalPresentationStyle {
        .none
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        currentViewController = nil
        removeTapDismissView()
        setPresented(false)
    }

    @objc private func outsideTapped() {
        dismissCurrent(animated: true)
    }

    private func dismissCurrent(animated: Bool) {
        currentViewController?.dismiss(animated: animated)
        currentViewController = nil
        removeTapDismissView()
        setPresented(false)
    }

    private func setPresented(_ presented: Bool) {
        guard isPresented != presented else { return }
        isPresented = presented
        onPresentationChanged?(presented)
    }

    private func installTapDismissView(in window: UIWindow?) {
        removeTapDismissView()
        guard let window else { return }
        let control = UIControl(frame: window.bounds)
        control.backgroundColor = .clear
        control.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        control.addTarget(self, action: #selector(outsideTapped), for: .touchUpInside)
        window.addSubview(control)
        tapDismissView = control
    }

    private func removeTapDismissView() {
        tapDismissView?.removeFromSuperview()
        tapDismissView = nil
    }

    private func topViewController(from view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let viewController = current as? UIViewController {
                return topMost(from: viewController)
            }
            responder = current.next
        }
        return topMost(from: view.window?.rootViewController)
    }

    private func topMost(from root: UIViewController?) -> UIViewController? {
        var current = root
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }
}
