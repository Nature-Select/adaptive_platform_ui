import UIKit

@available(iOS 26.0, *)
final class ElysOptionPopoverView: UIView {
    private enum Metrics {
        static let minWidth: CGFloat = 220
        static let maxWidth: CGFloat = 300
        static let verticalInset: CGFloat = 20
        static let horizontalInset: CGFloat = 20
        static let rowHeight: CGFloat = 38
        static let rowSpacing: CGFloat = 12
        static let separatorHorizontalInset: CGFloat = 20
        static let separatorVerticalSpacing: CGFloat = 16
        static let separatorHeight: CGFloat = 1
        static let cornerRadius: CGFloat = 34
        static let titleLeft: CGFloat = 46
        static let titleFont = UIFont.systemFont(ofSize: 18, weight: .medium)
    }

    private let assetLoader: ElysAssetLoader
    private let onSelect: (ElysInputOptionConfig) -> Void
    private let glassView: UIVisualEffectView = {
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = true
        return UIVisualEffectView(effect: effect)
    }()
    private let scrollView = UIScrollView(frame: .zero)
    private var items: [ElysInputOptionConfig]
    private var maximumHeight: CGFloat
    private var rows: [ElysOptionRowView] = []
    private var separators: [UIView] = []
    private weak var animationSourceView: UIView?

    init(
        items: [ElysInputOptionConfig],
        assetLoader: ElysAssetLoader,
        maximumHeight: CGFloat,
        onSelect: @escaping (ElysInputOptionConfig) -> Void
    ) {
        self.items = items
        self.assetLoader = assetLoader
        self.maximumHeight = maximumHeight
        self.onSelect = onSelect
        super.init(frame: CGRect(
            origin: .zero,
            size: Self.preferredSize(for: items, maximumHeight: maximumHeight)
        ))
        setup()
        rebuildRows()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        glassView.frame = bounds
        scrollView.frame = bounds
        layoutRows()
    }

    func animatePresentation(from sourceView: UIView) {
        animationSourceView = sourceView
        layoutIfNeeded()
        applyAnchorPoint(from: sourceView)
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.12, y: 0.12)
        UIView.animate(
            withDuration: 0.46,
            delay: 0,
            usingSpringWithDamping: 0.66,
            initialSpringVelocity: 0.82,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func animateDismissal(completion: @escaping () -> Void) {
        if let sourceView = animationSourceView {
            applyAnchorPoint(from: sourceView)
        }
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]
        ) {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.16, y: 0.16)
        } completion: { _ in
            completion()
        }
    }

    func update(items: [ElysInputOptionConfig]) {
        self.items = items
        frame.size = Self.preferredSize(for: items, maximumHeight: maximumHeight)
        rebuildRows()
    }

    func setMaximumHeight(_ maximumHeight: CGFloat) {
        guard self.maximumHeight != maximumHeight else { return }
        self.maximumHeight = maximumHeight
        frame.size = Self.preferredSize(for: items, maximumHeight: maximumHeight)
        setNeedsLayout()
    }

    private func setup() {
        backgroundColor = .clear
        layer.cornerCurve = .continuous
        layer.cornerRadius = Metrics.cornerRadius
        clipsToBounds = true
        glassView.layer.cornerCurve = .continuous
        glassView.layer.cornerRadius = Metrics.cornerRadius
        glassView.clipsToBounds = true
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        addSubview(glassView)
        glassView.contentView.addSubview(scrollView)
    }

    private func rebuildRows() {
        rows.forEach { $0.removeFromSuperview() }
        separators.forEach { $0.removeFromSuperview() }
        rows = items.map { item in
            let row = ElysOptionRowView(assetLoader: assetLoader)
            row.configure(item)
            row.onTap = { [weak self] selected in
                self?.onSelect(selected)
            }
            scrollView.addSubview(row)
            return row
        }
        separators = items.filter(\.showsSeparatorAfter).map { _ in
            let separator = UIView(frame: .zero)
            separator.backgroundColor = UIColor(red: 0x1F / 255.0, green: 0x1F / 255.0, blue: 0x25 / 255.0, alpha: 0.12)
            scrollView.addSubview(separator)
            return separator
        }
        setNeedsLayout()
    }

    private func layoutRows() {
        var y = Metrics.verticalInset
        var separatorIndex = 0
        rows.enumerated().forEach { index, row in
            row.frame = CGRect(
                x: Metrics.horizontalInset,
                y: y,
                width: max(1, scrollView.bounds.width - Metrics.horizontalInset * 2),
                height: Metrics.rowHeight
            )
            y += Metrics.rowHeight
            if items[index].showsSeparatorAfter,
               separatorIndex < separators.count {
                y += Metrics.separatorVerticalSpacing
                separators[separatorIndex].frame = CGRect(
                    x: Metrics.separatorHorizontalInset,
                    y: y,
                    width: max(1, scrollView.bounds.width - Metrics.separatorHorizontalInset * 2),
                    height: 1 / UIScreen.main.scale
                )
                y += Metrics.separatorHeight + Metrics.separatorVerticalSpacing
                separatorIndex += 1
            } else if index < rows.count - 1 {
                y += Metrics.rowSpacing
            }
        }
        scrollView.contentSize = CGSize(
            width: scrollView.bounds.width,
            height: y + Metrics.verticalInset
        )
        let overflows = scrollView.contentSize.height > scrollView.bounds.height + 0.5
        scrollView.isScrollEnabled = overflows
        scrollView.showsVerticalScrollIndicator = false
    }

    static func preferredSize(
        for items: [ElysInputOptionConfig],
        maximumHeight: CGFloat
    ) -> CGSize {
        let width = preferredWidth(for: items)
        let rawHeight = contentHeight(for: items)
        return CGSize(width: width, height: min(max(0, maximumHeight), rawHeight))
    }

    private static func preferredWidth(for items: [ElysInputOptionConfig]) -> CGFloat {
        let maxTitleWidth = items.map { item in
            (item.title as NSString).size(withAttributes: [.font: Metrics.titleFont]).width
        }.max() ?? 0
        let rawWidth = Metrics.horizontalInset * 2 + Metrics.titleLeft + ceil(maxTitleWidth)
        let paddedWidth = ceil(rawWidth / 4) * 4
        return paddedWidth.clamped(to: Metrics.minWidth...Metrics.maxWidth)
    }

    private static func contentHeight(for items: [ElysInputOptionConfig]) -> CGFloat {
        var height = Metrics.verticalInset * 2
        items.enumerated().forEach { index, item in
            height += Metrics.rowHeight
            if item.showsSeparatorAfter {
                height += Metrics.separatorVerticalSpacing * 2 + Metrics.separatorHeight
            } else if index < items.count - 1 {
                height += Metrics.rowSpacing
            }
        }
        return height
    }

    private func applyAnchorPoint(from sourceView: UIView) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let sourcePoint = sourceView.convert(
            CGPoint(x: sourceView.bounds.midX, y: sourceView.bounds.midY),
            to: self
        )
        let anchor = CGPoint(
            x: (sourcePoint.x / bounds.width).clamped(to: 0.08...0.92),
            y: (sourcePoint.y / bounds.height).clamped(to: 0.08...0.92)
        )
        setAnchorPoint(anchor, for: self)
    }

    private func setAnchorPoint(_ anchorPoint: CGPoint, for targetView: UIView) {
        let oldOrigin = targetView.frame.origin
        targetView.layer.anchorPoint = anchorPoint
        let newOrigin = targetView.frame.origin
        targetView.layer.position = CGPoint(
            x: targetView.layer.position.x - (newOrigin.x - oldOrigin.x),
            y: targetView.layer.position.y - (newOrigin.y - oldOrigin.y)
        )
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
