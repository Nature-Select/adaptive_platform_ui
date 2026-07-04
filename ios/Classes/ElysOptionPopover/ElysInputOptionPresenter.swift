import UIKit

@available(iOS 26.0, *)
final class ElysInputOptionPresenter: NSObject {
    private let assetLoader: ElysAssetLoader
    private var items: [ElysInputOptionConfig] = []
    private weak var currentPanel: ElysOptionPopoverView?
    private var dismissControl: UIControl?
    private var isPresented = false
    private var isAnimatingDismissal = false
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
        currentPanel?.update(items: items)
    }

    func update(item: ElysInputOptionConfig) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        currentPanel?.update(items: items)
    }

    func present(
        from sourceView: UIView,
        in containerView: UIView,
        onSelect: @escaping (ElysInputOptionConfig) -> Void
    ) {
        guard hasItems,
              let hostView = containerView.window ?? containerView.superview else { return }
        dismissCurrent(animated: false)

        let control = UIControl(frame: hostView.bounds)
        control.backgroundColor = .clear
        control.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        control.addTarget(self, action: #selector(outsideTapped), for: .touchUpInside)
        hostView.addSubview(control)
        dismissControl = control

        let panel = ElysOptionPopoverView(
            items: items,
            assetLoader: assetLoader
        ) { [weak self] item in
            self?.dismissCurrent(animated: true)
            onSelect(item)
        }
        panel.frame = panelFrame(for: panel.bounds.size, sourceView: sourceView, hostView: hostView)
        hostView.addSubview(panel)
        currentPanel = panel
        setPresented(true)
        panel.animatePresentation(from: sourceView)
    }

    func dismiss(animated: Bool) {
        dismissCurrent(animated: animated)
    }

    @objc private func outsideTapped() {
        dismissCurrent(animated: true)
    }

    private func dismissCurrent(animated: Bool) {
        guard let panel = currentPanel else {
            dismissControl?.removeFromSuperview()
            dismissControl = nil
            isAnimatingDismissal = false
            setPresented(false)
            return
        }
        guard !isAnimatingDismissal else { return }
        isAnimatingDismissal = true
        dismissControl?.isUserInteractionEnabled = false
        let finish = { [weak self, weak panel] in
            panel?.removeFromSuperview()
            self?.dismissControl?.removeFromSuperview()
            self?.dismissControl = nil
            self?.currentPanel = nil
            self?.isAnimatingDismissal = false
            self?.setPresented(false)
        }
        if animated {
            panel.animateDismissal(completion: finish)
        } else {
            finish()
        }
    }

    private func setPresented(_ presented: Bool) {
        guard isPresented != presented else { return }
        isPresented = presented
        onPresentationChanged?(presented)
    }

    private func panelFrame(
        for size: CGSize,
        sourceView: UIView,
        hostView: UIView
    ) -> CGRect {
        let sourceFrame = sourceView.convert(sourceView.bounds, to: hostView)
        let safe = hostView.safeAreaInsets
        let horizontalInset: CGFloat = 12
        let sourceCoverOffset: CGFloat = 0
        let x = min(
            max(horizontalInset, sourceFrame.minX - 22),
            max(horizontalInset, hostView.bounds.width - size.width - horizontalInset)
        )
        let preferredY = sourceFrame.maxY - size.height + sourceCoverOffset
        let y = max(safe.top + 8, preferredY)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
