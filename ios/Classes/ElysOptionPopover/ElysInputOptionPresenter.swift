import UIKit

@available(iOS 26.0, *)
struct ElysOptionPopoverLayout {
    private static let designMaximumHeight: CGFloat = 360
    private static let maximumScreenHeightRatio: CGFloat = 0.5
    private static let verticalMargin: CGFloat = 8
    private static let keyboardClearance: CGFloat = 8

    static func maximumHeight(
        hostBounds: CGRect,
        safeAreaInsets: UIEdgeInsets,
        sourceFrame: CGRect,
        keyboardTop: CGFloat?
    ) -> CGFloat {
        let limits = verticalLimits(
            hostBounds: hostBounds,
            safeAreaInsets: safeAreaInsets,
            sourceFrame: sourceFrame,
            keyboardTop: keyboardTop
        )
        let availableHeight = max(0, limits.bottom - limits.top)
        return min(
            designMaximumHeight,
            hostBounds.height * maximumScreenHeightRatio,
            availableHeight
        )
    }

    static func verticalLimits(
        hostBounds: CGRect,
        safeAreaInsets: UIEdgeInsets,
        sourceFrame: CGRect,
        keyboardTop: CGFloat?
    ) -> (top: CGFloat, bottom: CGFloat) {
        let top = hostBounds.minY + safeAreaInsets.top + verticalMargin
        let screenBottom = hostBounds.maxY - safeAreaInsets.bottom - verticalMargin
        var bottom = min(sourceFrame.maxY, screenBottom)
        if let keyboardTop {
            bottom = min(bottom, keyboardTop - keyboardClearance)
        }
        return (top, max(top, bottom))
    }
}

@available(iOS 26.0, *)
final class ElysInputOptionPresenter: NSObject {
    private let assetLoader: ElysAssetLoader
    private var items: [ElysInputOptionConfig] = []
    private weak var currentPanel: ElysOptionPopoverView?
    private weak var currentSourceView: UIView?
    private weak var currentHostView: UIView?
    private var currentKeyboardTop: CGFloat?
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
        relayout()
    }

    func update(item: ElysInputOptionConfig) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        currentPanel?.update(items: items)
        relayout()
    }

    func present(
        from sourceView: UIView,
        in containerView: UIView,
        keyboardTopInWindow: CGFloat?,
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

        let sourceFrame = sourceView.convert(sourceView.bounds, to: hostView)
        let keyboardTop = keyboardTopInHost(
            keyboardTopInWindow,
            window: containerView.window,
            hostView: hostView
        )
        let maximumHeight = ElysOptionPopoverLayout.maximumHeight(
            hostBounds: hostView.bounds,
            safeAreaInsets: hostView.safeAreaInsets,
            sourceFrame: sourceFrame,
            keyboardTop: keyboardTop
        )
        let panel = ElysOptionPopoverView(
            items: items,
            assetLoader: assetLoader,
            maximumHeight: maximumHeight
        ) { [weak self] item in
            self?.dismissCurrent(animated: true)
            onSelect(item)
        }
        panel.frame = panelFrame(
            for: panel.bounds.size,
            sourceFrame: sourceFrame,
            hostView: hostView,
            keyboardTop: keyboardTop
        )
        hostView.addSubview(panel)
        currentPanel = panel
        currentSourceView = sourceView
        currentHostView = hostView
        currentKeyboardTop = keyboardTop
        setPresented(true)
        panel.animatePresentation(from: sourceView)
    }

    func updateKeyboard(topInWindow: CGFloat?, window: UIWindow?) {
        guard let hostView = currentHostView else { return }
        currentKeyboardTop = keyboardTopInHost(
            topInWindow,
            window: window,
            hostView: hostView
        )
        relayout()
    }

    func relayout() {
        guard let panel = currentPanel,
              let sourceView = currentSourceView,
              let hostView = currentHostView else { return }
        let sourceFrame = sourceView.convert(sourceView.bounds, to: hostView)
        let maximumHeight = ElysOptionPopoverLayout.maximumHeight(
            hostBounds: hostView.bounds,
            safeAreaInsets: hostView.safeAreaInsets,
            sourceFrame: sourceFrame,
            keyboardTop: currentKeyboardTop
        )
        panel.setMaximumHeight(maximumHeight)
        panel.frame = panelFrame(
            for: panel.bounds.size,
            sourceFrame: sourceFrame,
            hostView: hostView,
            keyboardTop: currentKeyboardTop
        )
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
            currentSourceView = nil
            currentHostView = nil
            currentKeyboardTop = nil
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
            self?.currentSourceView = nil
            self?.currentHostView = nil
            self?.currentKeyboardTop = nil
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
        sourceFrame: CGRect,
        hostView: UIView,
        keyboardTop: CGFloat?
    ) -> CGRect {
        let horizontalInset: CGFloat = 12
        let x = min(
            max(hostView.bounds.minX + horizontalInset, sourceFrame.minX - 22),
            max(
                hostView.bounds.minX + horizontalInset,
                hostView.bounds.maxX - size.width - horizontalInset
            )
        )
        let limits = ElysOptionPopoverLayout.verticalLimits(
            hostBounds: hostView.bounds,
            safeAreaInsets: hostView.safeAreaInsets,
            sourceFrame: sourceFrame,
            keyboardTop: keyboardTop
        )
        let y = max(limits.top, limits.bottom - size.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private func keyboardTopInHost(
        _ topInWindow: CGFloat?,
        window: UIWindow?,
        hostView: UIView
    ) -> CGFloat? {
        guard let topInWindow, let window else { return nil }
        return window.convert(
            CGPoint(x: window.bounds.midX, y: topInWindow),
            to: hostView
        ).y
    }
}
