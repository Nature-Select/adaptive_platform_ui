import UIKit

@available(iOS 26.0, *)
private final class ElysInputAccessoryButton: UIButton {
    var hitSlop: CGFloat = 0

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -hitSlop, dy: -hitSlop).contains(point)
    }
}

@available(iOS 26.0, *)
final class ElysInputBarView: UIView, UITextViewDelegate, UIGestureRecognizerDelegate {
    let assetLoader: ElysAssetLoader
    private let glassView: UIVisualEffectView
    let textView = UITextView(frame: .zero)
    let placeholderLabel = UILabel(frame: .zero)
    private let leadingButton = ElysInputAccessoryButton(frame: .zero)
    private let trailingBackgroundView = UIView(frame: .zero)
    private let trailingButton = ElysInputAccessoryButton(frame: .zero)
    private lazy var accessoryTapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(accessoryTappedByGesture(_:)))
        gesture.cancelsTouchesInView = true
        gesture.delegate = self
        return gesture
    }()
    private var expanded = false
    private var leadingAction: ElysActionConfig?
    private var collapsedTrailingAction: ElysActionConfig?
    private var expandedTrailingAction: ElysActionConfig?
    private var trailingAccessorySuppressed = false
    private var appliedLeadingIconMaxSize: CGFloat = -1
    var inputText = ""
    var inputPrefix: ElysInputPrefixConfig?
    var isApplyingTextStorage = false
    var onTextChanged: ((String) -> Void)?
    var onPrefixDeleted: ((String) -> Void)?
    var onSubmit: ((String) -> Void)?
    var onPreferredHeightChanged: (() -> Void)?
    var onAccessoryTapped: ((String) -> Void)?
    var onLeadingAccessoryTapped: ((String, UIView) -> Void)?

    init(frame: CGRect, assetLoader: ElysAssetLoader) {
        self.assetLoader = assetLoader
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = true
        glassView = UIVisualEffectView(effect: effect)
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCornerRadius(expanded ? ElysBarMetrics.expandedInputCornerRadius : bounds.height / 2)
        glassView.frame = bounds
        refreshLeadingButtonImageIfNeeded()
        let accessory = accessoryLayout()
        leadingButton.frame = accessory.leading
        trailingBackgroundView.frame = accessory.trailingBackground
        trailingBackgroundView.layer.cornerRadius = trailingBackgroundView.bounds.height / 2
        trailingButton.frame = accessory.trailing
        textView.frame = accessory.text
        layoutTextInsets()
        if (!usesMultilineLayout || usesCompactMultilineLayout) && !textView.isFirstResponder {
            textView.setContentOffset(.zero, animated: false)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for button in [leadingButton, trailingButton] where canHitAccessory(button) {
            let buttonPoint = convert(point, to: button)
            if button.point(inside: buttonPoint, with: event) {
                return button
            }
        }
        return super.hitTest(point, with: event)
    }

    func configure(_ config: ElysInputConfig) {
        placeholderLabel.text = config.placeholder
        setPrefix(config.prefix)
        leadingAction = config.leadingAction
        collapsedTrailingAction = config.collapsedTrailingAction
        expandedTrailingAction = config.expandedTrailingAction
        configureAccessoryButtons()
        setText(config.text, notify: false)
    }

    func focus() {
        textView.isUserInteractionEnabled = true
        guard window != nil else { DispatchQueue.main.async { [weak self] in self?.focus() }; return }
        textView.becomeFirstResponder()
        DispatchQueue.main.async { [weak self] in self?.textView.becomeFirstResponder() }
    }

    func blur() {
        textView.resignFirstResponder()
    }

    var isTextInputFocused: Bool {
        textView.isFirstResponder
    }

    func refocusIfNeeded(_ shouldRefocus: Bool) {
        guard shouldRefocus else { return }
        DispatchQueue.main.async { [weak self] in
            self?.textView.becomeFirstResponder()
        }
    }

    func prepareForDismissalAnimation() {
        // 不再栅格化退场中的玻璃胶囊：对 live 玻璃拍位图会把退化灰板固化
        // 得更明显（性能动机已随图标缓存消失）。
        textView.isUserInteractionEnabled = false
        setTrailingAccessorySuppressed(true)
        textView.isScrollEnabled = false
        textView.textContainer.maximumNumberOfLines = 1
        textView.textContainer.lineBreakMode = .byTruncatingTail
        placeholderLabel.numberOfLines = 1
        placeholderLabel.lineBreakMode = .byTruncatingTail
        setNeedsLayout()
        layoutIfNeeded()
        textView.setContentOffset(.zero, animated: false)
    }

    func finishDismissalAnimation() {
        textView.isUserInteractionEnabled = true
    }

    func setText(_ text: String, notify: Bool) {
        guard inputText != text else { return }
        // 组词（marked text）期间到达的外部文本要么是滞后的 setConfig 回声，
        // 要么是终将随回声收敛的程序性写入；此时重写 attributedText 会终结
        // IME 会话，把拼音以裸字母上屏。跳过，等组词结束后由同步链路收敛。
        guard textView.markedTextRange == nil else { return }
        inputText = text
        renderInputText(cursorBodyOffset: (text as NSString).length)
        notifyPreferredHeightChanged()
        if notify { onTextChanged?(inputText) }
    }

    func setExpanded(_ expanded: Bool) {
        guard self.expanded != expanded else { return }
        self.expanded = expanded
        textView.isScrollEnabled = expanded
        textView.textContainer.maximumNumberOfLines = expanded ? 0 : 1
        textView.textContainer.lineBreakMode = expanded ? .byWordWrapping : .byTruncatingTail
        placeholderLabel.numberOfLines = expanded ? 4 : 1
        placeholderLabel.lineBreakMode = expanded ? .byWordWrapping : .byTruncatingTail
        configureAccessoryButtons()
        setNeedsLayout()
        notifyPreferredHeightChanged()
    }

    func setTrailingAccessorySuppressed(_ suppressed: Bool, animated: Bool = false) {
        guard trailingAccessorySuppressed != suppressed else { return }
        trailingAccessorySuppressed = suppressed
        applyTrailingAccessoryVisibility()
        if animated && !suppressed && !trailingButton.isHidden {
            trailingButton.alpha = 0
            trailingBackgroundView.alpha = 0
            UIView.animate(
                withDuration: 0.18,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.trailingButton.alpha = 1
                self.trailingBackgroundView.alpha = 1
            }
        }
    }

    func preferredExpandedHeight(for width: CGFloat) -> CGFloat {
        let font = textView.font ?? .systemFont(ofSize: ElysBarMetrics.inputFontSize)
        let lineHeight = font.lineHeight
        let fixedInsets = ElysBarMetrics.expandedTextTopInset
            + ElysBarMetrics.expandedTextBottomInset
        let minHeight = ceil(lineHeight + fixedInsets)
        let maxHeight = ceil(lineHeight * 4.5 + fixedInsets)
        let textWidth = max(1, width - ElysBarMetrics.expandedTextHorizontalInset * 2)
        let measuredTextHeight = measuredInputTextHeight(width: textWidth, font: font)
        return min(max(minHeight, measuredTextHeight + fixedInsets), maxHeight)
    }

    var text: String {
        inputText
    }

    func updateCornerRadius(_ radius: CGFloat) {
        layer.cornerRadius = radius
        glassView.layer.cornerRadius = radius
    }

    private func setup() {
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.masksToBounds = true
        glassView.layer.cornerCurve = .continuous
        glassView.clipsToBounds = true

        textView.delegate = self
        textView.font = .systemFont(ofSize: ElysBarMetrics.inputFontSize, weight: .medium)
        textView.textColor = UIColor(
            red: 0x1F / 255.0,
            green: 0x1F / 255.0,
            blue: 0x25 / 255.0,
            alpha: 1.0
        )
        textView.tintColor = UIColor(
            red: 0x1F / 255.0,
            green: 0x1F / 255.0,
            blue: 0x25 / 255.0,
            alpha: 1.0
        )
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.returnKeyType = .default
        textView.keyboardDismissMode = .interactive
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false

        configureButtonShell(leadingButton)
        configureButtonShell(trailingButton)
        trailingBackgroundView.backgroundColor = UIColor(
            red: 0x1F / 255.0,
            green: 0x1F / 255.0,
            blue: 0x25 / 255.0,
            alpha: 0.10
        )
        trailingBackgroundView.layer.cornerCurve = .continuous
        trailingBackgroundView.isUserInteractionEnabled = false
        leadingButton.addTarget(self, action: #selector(leadingTapped), for: .touchUpInside)
        trailingButton.addTarget(self, action: #selector(trailingTapped), for: .touchUpInside)
        [leadingButton, trailingButton].forEach { button in
            button.addTarget(self, action: #selector(accessoryTouchDown(_:)), for: [.touchDown, .touchDragEnter])
            button.addTarget(self, action: #selector(accessoryTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        }

        placeholderLabel.font = textView.font
        placeholderLabel.textColor = UIColor(
            red: 0x1F / 255.0,
            green: 0x1F / 255.0,
            blue: 0x25 / 255.0,
            alpha: 0.5
        )
        placeholderLabel.isUserInteractionEnabled = false

        addSubview(glassView)
        addSubview(trailingBackgroundView)
        addSubview(leadingButton)
        addSubview(trailingButton)
        addSubview(textView)
        addSubview(placeholderLabel)
        addGestureRecognizer(accessoryTapGesture)
        setExpanded(false)
        updatePlaceholder()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === accessoryTapGesture else { return true }
        return hitAccessory(at: touch.location(in: self)) != nil
    }

    func updatePlaceholder() {
        // textView.hasText 覆盖组词阶段：marked text 不进 inputText，但占位符不能压在拼音上。
        placeholderLabel.isHidden = inputPrefix != nil || !inputText.isEmpty || textView.hasText
    }

    func notifyPreferredHeightChanged() {
        guard expanded else { return }
        onPreferredHeightChanged?()
    }

    private func layoutTextInsets() {
        let lineHeight = textView.font?.lineHeight ?? ElysBarMetrics.inputFontSize
        let verticalInset = usesTallMultilineLayout
            ? ElysBarMetrics.expandedTextTopInset
            : max(0, (textView.bounds.height - lineHeight) / 2)
        let bottomInset: CGFloat = 0
        textView.textContainerInset = UIEdgeInsets(
            top: verticalInset,
            left: 0,
            bottom: bottomInset,
            right: 0
        )
        placeholderLabel.frame = CGRect(
            x: textView.frame.minX,
            y: textView.frame.minY + verticalInset,
            width: textView.frame.width,
            height: usesTallMultilineLayout ? max(lineHeight, textView.frame.height - verticalInset) : lineHeight
        )
    }

    private var usesMultilineLayout: Bool {
        expanded
    }

    private var usesCompactMultilineLayout: Bool {
        expanded && bounds.height <= ElysBarMetrics.inputCollapsedHeight + 8
    }

    private var usesTallMultilineLayout: Bool {
        expanded && !usesCompactMultilineLayout
    }

    private func accessoryLayout() -> (
        leading: CGRect,
        trailingBackground: CGRect,
        trailing: CGRect,
        text: CGRect
    ) {
        let compactLeading = !usesTallMultilineLayout
        let leadingSize = compactLeading
            ? ElysBarMetrics.inputCompactLeadingAccessorySize
            : ElysBarMetrics.inputLeadingAccessorySize
        let leadingInset = compactLeading
            ? ElysBarMetrics.inputCompactLeadingAccessoryOuterInset
            : ElysBarMetrics.inputExpandedLeadingAccessoryOuterInset
        let trailingSize = ElysBarMetrics.inputTrailingAccessorySize
        let multiline = usesMultilineLayout
        let y = multiline
            ? max(8, bounds.height - trailingSize - 14)
            : max(0, (bounds.height - trailingSize) / 2)
        let leadingY = usesTallMultilineLayout
            ? max(8, bounds.height - leadingSize - ElysBarMetrics.inputExpandedLeadingAccessoryBottomInset)
            : max(0, (bounds.height - leadingSize) / 2)
        let leading = CGRect(
            x: leadingInset,
            y: leadingY,
            width: leadingSize,
            height: leadingSize
        )
        let trailing = CGRect(
            x: bounds.width - ElysBarMetrics.inputTrailingAccessoryOuterInset - trailingSize,
            y: y,
            width: trailingSize,
            height: trailingSize
        )
        let backgroundSize = ElysBarMetrics.inputTrailingBackgroundSize
        let trailingBackground = CGRect(
            x: trailing.midX - backgroundSize / 2,
            y: trailing.midY - backgroundSize / 2,
            width: backgroundSize,
            height: backgroundSize
        )
        let text: CGRect
        if multiline {
            if bounds.height <= ElysBarMetrics.inputCollapsedHeight + 8 {
                let textMinX = leadingButton.isHidden
                    ? leadingInset
                    : leading.maxX + ElysBarMetrics.inputAccessoryTextGap
                let textMaxX = trailingButton.isHidden
                    ? bounds.width - ElysBarMetrics.inputAccessoryOuterInset
                    : trailing.minX - ElysBarMetrics.inputAccessoryTextGap
                text = CGRect(
                    x: textMinX,
                    y: 0,
                    width: max(1, textMaxX - textMinX),
                    height: bounds.height
                )
            } else {
                text = CGRect(
                    x: ElysBarMetrics.expandedTextHorizontalInset,
                    y: 0,
                    width: max(1, bounds.width - ElysBarMetrics.expandedTextHorizontalInset * 2),
                    height: max(1, bounds.height - ElysBarMetrics.expandedTextBottomInset)
                )
            }
        } else {
            let textMinX = leadingButton.isHidden
                ? leadingInset
                : leading.maxX + ElysBarMetrics.inputAccessoryTextGap
            let textMaxX = trailingButton.isHidden
                ? bounds.width - ElysBarMetrics.inputAccessoryOuterInset
                : trailing.minX - ElysBarMetrics.inputAccessoryTextGap
            text = CGRect(
                x: textMinX,
                y: 0,
                width: max(1, textMaxX - textMinX),
                height: bounds.height
            )
        }
        return (
            leading,
            trailingBackground,
            trailing,
            text
        )
    }

    private func configureButtonShell(_ button: UIButton) {
        button.imageView?.contentMode = .scaleAspectFit
        button.adjustsImageWhenHighlighted = true
        if let button = button as? ElysInputAccessoryButton {
            button.hitSlop = ElysBarMetrics.inputAccessoryHitSlop
        }
    }

    private func canHitAccessory(_ button: UIButton) -> Bool {
        !button.isHidden
            && button.alpha > 0.01
            && button.isUserInteractionEnabled
            && button.image(for: .normal) != nil
    }

    private func hitAccessory(at point: CGPoint) -> UIButton? {
        for button in [leadingButton, trailingButton] where canHitAccessory(button) {
            let buttonPoint = convert(point, to: button)
            if button.point(inside: buttonPoint, with: nil) {
                return button
            }
        }
        return nil
    }

    @objc private func accessoryTouchDown(_ button: UIButton) {
        let isLeadingAccessory = button === leadingButton
        animateAccessory(
            button,
            scale: isLeadingAccessory ? 1.20 : 1.08,
            damping: isLeadingAccessory ? 0.62 : 0.78,
            velocity: isLeadingAccessory ? 0.75 : 0.35
        )
    }

    @objc private func accessoryTouchUp(_ button: UIButton) {
        let isLeadingAccessory = button === leadingButton
        animateAccessory(
            button,
            scale: 1,
            damping: isLeadingAccessory ? 0.56 : 0.72,
            velocity: isLeadingAccessory ? 0.85 : 0.35
        )
    }

    private func animateAccessory(
        _ button: UIButton,
        scale: CGFloat,
        damping: CGFloat,
        velocity: CGFloat
    ) {
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: damping,
            initialSpringVelocity: velocity,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            button.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    private func configureAccessoryButtons() {
        appliedLeadingIconMaxSize = -1
        refreshLeadingButtonImageIfNeeded()
        configure(
            trailingButton,
            action: expanded ? expandedTrailingAction : collapsedTrailingAction,
            maxSize: ElysBarMetrics.inputTrailingIconMaxSize
        )
        applyTrailingAccessoryVisibility()
        setNeedsLayout()
    }

    private func refreshLeadingButtonImageIfNeeded() {
        let maxSize = usesTallMultilineLayout
            ? ElysBarMetrics.inputLeadingIconMaxSize
            : ElysBarMetrics.inputCompactLeadingIconMaxSize
        guard appliedLeadingIconMaxSize != maxSize else { return }
        appliedLeadingIconMaxSize = maxSize
        configure(leadingButton, action: leadingAction, maxSize: maxSize)
    }

    private func applyTrailingAccessoryVisibility() {
        let hasImage = trailingButton.image(for: .normal) != nil
        let hidden = trailingAccessorySuppressed || !hasImage
        trailingButton.isHidden = hidden
        trailingBackgroundView.isHidden = hidden
        if hidden {
            trailingButton.alpha = 0
            trailingBackgroundView.alpha = 0
        } else if trailingButton.alpha == 0 {
            trailingButton.alpha = 1
            trailingBackgroundView.alpha = 1
        }
    }

    private func configure(_ button: UIButton, action: ElysActionConfig?, maxSize: CGFloat) {
        guard let action else {
            button.isHidden = true
            button.setImage(nil, for: .normal)
            return
        }
        button.isHidden = false
        button.accessibilityLabel = action.accessibilityLabel ?? action.id
        button.setImage(
            assetLoader.imageAspectFit(
                named: action.icon,
                maxSize: CGSize(
                    width: maxSize,
                    height: maxSize
                )
            ),
            for: .normal
        )
    }

    @objc private func leadingTapped() {
        guard let action = leadingAction else { return }
        if let onLeadingAccessoryTapped {
            onLeadingAccessoryTapped(action.id, leadingButton)
        } else {
            onAccessoryTapped?(action.id)
        }
    }

    @objc private func trailingTapped() {
        let action = expanded ? expandedTrailingAction : collapsedTrailingAction
        guard let action else { return }
        // 未提交的组词拼音不随发送外发；先丢弃，让随后 Dart 侧的清空
        // 回声不再被组词守卫拦下。
        discardMarkedTextIfNeeded()
        if expandedTrailingAction?.id == action.id && expanded {
            onSubmit?(text)
        }
        onAccessoryTapped?(action.id)
    }

    private func discardMarkedTextIfNeeded() {
        guard textView.markedTextRange != nil else { return }
        isApplyingTextStorage = true
        textView.unmarkText()
        isApplyingTextStorage = false
        renderInputText()
    }

    @objc private func accessoryTappedByGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended,
              let button = hitAccessory(at: gesture.location(in: self)) else { return }
        if button === leadingButton {
            leadingTapped()
        } else if button === trailingButton {
            trailingTapped()
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        syncTextFromTextViewIfNeeded()
    }
}
