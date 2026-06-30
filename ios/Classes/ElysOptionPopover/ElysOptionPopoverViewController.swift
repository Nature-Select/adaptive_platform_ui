import UIKit

@available(iOS 26.0, *)
final class ElysOptionPopoverViewController: UIViewController {
    private enum Metrics {
        static let width: CGFloat = 160
        static let maxHeight: CGFloat = 560
        static let verticalInset: CGFloat = 16
        static let horizontalInset: CGFloat = 16
        static let rowHeight: CGFloat = 32
        static let rowSpacing: CGFloat = 16
        static let cornerRadius: CGFloat = 20
    }

    private let assetLoader: ElysAssetLoader
    private let onSelect: (ElysInputOptionConfig) -> Void
    private let glassView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
    private let scrollView = UIScrollView(frame: .zero)
    private var items: [ElysInputOptionConfig]
    private var rows: [ElysOptionRowView] = []

    init(
        items: [ElysInputOptionConfig],
        assetLoader: ElysAssetLoader,
        onSelect: @escaping (ElysInputOptionConfig) -> Void
    ) {
        self.items = items
        self.assetLoader = assetLoader
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        updatePreferredContentSize()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        rebuildRows()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        glassView.frame = view.bounds
        scrollView.frame = view.bounds
        layoutRows()
    }

    func update(items: [ElysInputOptionConfig]) {
        self.items = items
        updatePreferredContentSize()
        if isViewLoaded { rebuildRows() }
    }

    private func setup() {
        view.backgroundColor = .clear
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = Metrics.cornerRadius
        view.clipsToBounds = true
        glassView.layer.cornerCurve = .continuous
        glassView.layer.cornerRadius = Metrics.cornerRadius
        glassView.clipsToBounds = true
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(glassView)
        glassView.contentView.addSubview(scrollView)
    }

    private func rebuildRows() {
        rows.forEach { $0.removeFromSuperview() }
        rows = items.map { item in
            let row = ElysOptionRowView(assetLoader: assetLoader)
            row.configure(item)
            row.onTap = { [weak self] selected in
                self?.onSelect(selected)
            }
            scrollView.addSubview(row)
            return row
        }
        view.setNeedsLayout()
    }

    private func layoutRows() {
        var y = Metrics.verticalInset
        rows.forEach { row in
            row.frame = CGRect(
                x: Metrics.horizontalInset,
                y: y,
                width: max(1, scrollView.bounds.width - Metrics.horizontalInset * 2),
                height: Metrics.rowHeight
            )
            y += Metrics.rowHeight + Metrics.rowSpacing
        }
        if !rows.isEmpty { y -= Metrics.rowSpacing }
        scrollView.contentSize = CGSize(
            width: scrollView.bounds.width,
            height: y + Metrics.verticalInset
        )
    }

    private func updatePreferredContentSize() {
        let itemCount = CGFloat(items.count)
        let rawHeight = Metrics.verticalInset * 2
            + itemCount * Metrics.rowHeight
            + max(0, itemCount - 1) * Metrics.rowSpacing
        preferredContentSize = CGSize(
            width: Metrics.width,
            height: min(Metrics.maxHeight, rawHeight)
        )
    }
}

@available(iOS 26.0, *)
private final class ElysOptionRowView: UIControl {
    private enum Metrics {
        static let iconBackgroundSize: CGFloat = 32
        static let iconSize: CGFloat = 20
        static let titleLeft: CGFloat = 44
    }

    private let assetLoader: ElysAssetLoader
    private let iconBackgroundView = UIView(frame: .zero)
    private let iconView = UIImageView(frame: .zero)
    private let titleLabel = UILabel(frame: .zero)
    private var item: ElysInputOptionConfig?
    var onTap: ((ElysInputOptionConfig) -> Void)?

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
        iconBackgroundView.frame = CGRect(
            x: 0,
            y: (bounds.height - Metrics.iconBackgroundSize) / 2,
            width: Metrics.iconBackgroundSize,
            height: Metrics.iconBackgroundSize
        )
        iconBackgroundView.layer.cornerRadius = Metrics.iconBackgroundSize / 2
        iconView.frame = CGRect(
            x: iconBackgroundView.frame.minX + (Metrics.iconBackgroundSize - Metrics.iconSize) / 2,
            y: iconBackgroundView.frame.minY + (Metrics.iconBackgroundSize - Metrics.iconSize) / 2,
            width: Metrics.iconSize,
            height: Metrics.iconSize
        )
        titleLabel.frame = CGRect(
            x: Metrics.titleLeft,
            y: 0,
            width: max(1, bounds.width - Metrics.titleLeft),
            height: bounds.height
        )
    }

    func configure(_ item: ElysInputOptionConfig) {
        self.item = item
        isEnabled = item.enabled
        accessibilityLabel = item.accessibilityLabel ?? item.title
        accessibilityTraits = item.enabled ? [.button] : [.button, .notEnabled]
        iconView.image = assetLoader.imageAspectFit(
            named: item.icon,
            maxSize: CGSize(width: Metrics.iconSize, height: Metrics.iconSize)
        )
        titleLabel.text = item.title
        let alpha: CGFloat = item.enabled ? 1 : 0.30
        iconBackgroundView.alpha = alpha
        iconView.alpha = alpha
        titleLabel.textColor = UIColor(
            red: 0x1F / 255.0,
            green: 0x1F / 255.0,
            blue: 0x25 / 255.0,
            alpha: item.enabled ? 1 : 0.35
        )
    }

    private func setup() {
        backgroundColor = .clear
        iconBackgroundView.backgroundColor = UIColor(
            red: 0xF5 / 255.0,
            green: 0xF5 / 255.0,
            blue: 0xF5 / 255.0,
            alpha: 1
        )
        iconBackgroundView.isUserInteractionEnabled = false
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82
        titleLabel.isUserInteractionEnabled = false
        addSubview(iconBackgroundView)
        addSubview(iconView)
        addSubview(titleLabel)
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    @objc private func tapped() {
        guard let item, item.enabled else { return }
        onTap?(item)
    }

    @objc private func touchDown() {
        animateScale(0.985, alpha: 0.72)
    }

    @objc private func touchUp() {
        animateScale(1, alpha: 1)
    }

    private func animateScale(_ scale: CGFloat, alpha: CGFloat) {
        UIView.animate(
            withDuration: 0.20,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.35,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.alpha = alpha
        }
    }
}
