import UIKit

@available(iOS 26.0, *)
final class ElysActionButton: UIControl {
    private let assetLoader: ElysAssetLoader
    private let glassEffect: UIGlassEffect
    private let glassView: UIVisualEffectView
    private let imageView = UIImageView(frame: .zero)
    private let badgeLabel = UILabel(frame: .zero)
    private var action: ElysActionConfig?
    private var iconSize: CGFloat = 36
    var onTap: ((ElysActionConfig) -> Void)?

    init(assetLoader: ElysAssetLoader) {
        self.assetLoader = assetLoader
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = true
        glassEffect = effect
        glassView = UIVisualEffectView(effect: effect)
        super.init(frame: .zero)
        setup()
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCornerRadius(bounds.height / 2)
        glassView.frame = bounds
        imageView.frame = bounds
        layoutBadge()
    }

    func configure(action: ElysActionConfig, iconSize: CGFloat) {
        self.action = action
        self.iconSize = iconSize
        accessibilityLabel = action.accessibilityLabel ?? action.id
        imageView.image = assetLoader.image(
            named: action.icon,
            size: CGSize(width: iconSize, height: iconSize)
        )
        configureBadge(action.badgeCount)
    }

    func updateCornerRadius(_ radius: CGFloat) {
        layer.cornerRadius = radius
        glassView.layer.cornerRadius = radius
    }

    // 只管非玻璃内容；玻璃开关由 ElysLiquidBarView 按切换时序编排——
    // effect 的消融/物化过渡在动画飞行中会渲染出灰色玻璃底板（视频逐帧
    // 实锤），只允许在静止态无感切换。
    func setContentVisible(_ visible: Bool) {
        imageView.alpha = visible ? 1 : 0
        badgeLabel.alpha = visible ? 1 : 0
    }

    func setGlassVisible(_ visible: Bool) {
        glassView.effect = visible ? glassEffect : nil
    }

    private func setup() {
        layer.cornerCurve = .continuous
        clipsToBounds = true
        glassView.layer.cornerCurve = .continuous
        glassView.clipsToBounds = true
        glassView.isUserInteractionEnabled = false
        imageView.contentMode = .center
        imageView.isUserInteractionEnabled = false
        badgeLabel.backgroundColor = .systemRed
        badgeLabel.textColor = .white
        badgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        badgeLabel.textAlignment = .center
        badgeLabel.clipsToBounds = true
        badgeLabel.isUserInteractionEnabled = false
        badgeLabel.isHidden = true
        addSubview(glassView)
        addSubview(imageView)
        addSubview(badgeLabel)
    }

    private func configureBadge(_ count: Int?) {
        guard let count, count > 0 else {
            badgeLabel.isHidden = true
            badgeLabel.text = nil
            return
        }
        badgeLabel.isHidden = false
        badgeLabel.text = count > 99 ? "99+" : "\(count)"
        setNeedsLayout()
    }

    private func layoutBadge() {
        guard !badgeLabel.isHidden else { return }
        let text = badgeLabel.text ?? ""
        let textWidth = (text as NSString).size(withAttributes: [.font: badgeLabel.font as Any]).width
        let badgeHeight: CGFloat = 18
        let badgeWidth = max(badgeHeight, ceil(textWidth) + 10)
        let iconRight = bounds.midX + iconSize / 2
        let iconTop = bounds.midY - iconSize / 2
        badgeLabel.frame = CGRect(
            x: min(bounds.width - badgeWidth - 5, max(bounds.midX, iconRight - 6)),
            y: max(4, iconTop - 6),
            width: badgeWidth,
            height: badgeHeight
        )
        badgeLabel.layer.cornerRadius = badgeHeight / 2
    }

    @objc private func tapped() {
        guard let action else { return }
        onTap?(action)
    }

    @objc private func touchDown() {
        animateScale(1.08, damping: 0.78)
    }

    @objc private func touchUp() {
        animateScale(1, damping: 0.72)
    }

    private func animateScale(_ scale: CGFloat, damping: CGFloat) {
        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            usingSpringWithDamping: damping,
            initialSpringVelocity: 0.35,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
}
