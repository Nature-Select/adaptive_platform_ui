import UIKit

@available(iOS 26.0, *)
final class ElysOptionRowView: UIControl {
    private enum Metrics {
        static let iconBackgroundSize: CGFloat = 38
        static let iconSize: CGFloat = 24
        static let titleLeft: CGFloat = 46
        static let titleFont = UIFont.systemFont(ofSize: 18, weight: .medium)
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
        titleLabel.font = Metrics.titleFont
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
