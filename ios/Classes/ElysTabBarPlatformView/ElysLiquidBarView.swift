import UIKit

@available(iOS 26.0, *)
final class ElysLiquidBarView: UIView {
    let referenceTabBar = UITabBar(frame: .zero)
    let blankTapView = UIControl(frame: .zero)
    let glassContainerView: ElysPassthroughGlassContainerView
    let leadingButton: ElysActionButton
    let sideButton: ElysActionButton
    let tabBar: ElysRightTabBarView
    let inputBar: ElysInputBarView
    let optionPresenter: ElysInputOptionPresenter
    let interactionCoordinator = ElysBarInteractionCoordinator()
    private var config: ElysBarConfig
    var layoutEmitScheduled = false
    var pendingLayoutAnimationDuration = ElysBarMetrics.animationDuration
    var lastLayoutPayloadSignature: String?
    var keyboardDisplayLink: CADisplayLink?
    var onEvent: ((String, [String: Any]) -> Void)?

    init(config: ElysBarConfig, assetLoader: ElysAssetLoader) {
        self.config = config
        let glassContainerEffect = UIGlassContainerEffect()
        glassContainerEffect.spacing = ElysBarMetrics.glassMergeSpacing
        glassContainerView = ElysPassthroughGlassContainerView(effect: glassContainerEffect)
        leadingButton = ElysActionButton(assetLoader: assetLoader)
        sideButton = ElysActionButton(assetLoader: assetLoader)
        tabBar = ElysRightTabBarView(assetLoader: assetLoader)
        inputBar = ElysInputBarView(frame: .zero, assetLoader: assetLoader)
        optionPresenter = ElysInputOptionPresenter(assetLoader: assetLoader)
        super.init(frame: .zero)
        setup()
        observeKeyboard()
        apply(config, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { keyboardDisplayLink?.invalidate(); NotificationCenter.default.removeObserver(self) }

    override func layoutSubviews() {
        super.layoutSubviews()
        blankTapView.frame = bounds
        glassContainerView.frame = bounds
        layoutNormal()
        layoutInput(interactionCoordinator.renderState)
    }

    func apply(_ config: ElysBarConfig, animated: Bool = true) {
        self.config = config
        overrideUserInterfaceStyle = config.isDark ? .dark : .light
        configureIcons()
        inputBar.configure(config.input)
        optionPresenter.configure(items: config.input.optionItems)
        setInputActive(config.inputActive, animated: animated, emit: false)
        setNeedsLayout()
    }

    func setInputActive(_ active: Bool) {
        setInputActive(active, animated: true, emit: true)
    }

    func setInputText(_ text: String) {
        inputBar.setText(text, notify: false)
    }

    func updateInputOption(_ item: ElysInputOptionConfig) {
        optionPresenter.update(item: item)
    }

    func focusInput() {
        if !interactionCoordinator.inputActive {
            setInputActive(true, animated: true, emit: true)
        }
        setNeedsLayout(); layoutIfNeeded()
        inputBar.focus()
        DispatchQueue.main.async { [weak self] in self?.inputBar.focus() }
    }

    func blurInput() {
        inputBar.blur()
    }

    func intrinsicHeight() -> CGFloat {
        measuredLayout().totalHeight
    }

    private func setup() {
        backgroundColor = .clear
        blankTapView.backgroundColor = .clear
        blankTapView.alpha = 0
        blankTapView.isHidden = true
        blankTapView.isUserInteractionEnabled = false
        blankTapView.addTarget(self, action: #selector(blankTapped), for: .touchUpInside)
        referenceTabBar.isHidden = true
        referenceTabBar.isTranslucent = true
        [referenceTabBar, blankTapView, glassContainerView, tabBar].forEach {
            addSubview($0)
        }
        [leadingButton, inputBar, sideButton].forEach {
            glassContainerView.contentView.addSubview($0)
        }
        inputBar.alpha = 0
        sideButton.alpha = 0
        inputBar.transform = hiddenInputTransform()
        sideButton.transform = hiddenSideTransform()
        leadingButton.onTap = { [weak self] action in
            guard let self else { return }
            self.setInputActive(true, animated: true, emit: true)
            self.onEvent?("leadingActionTapped", ["id": action.id])
        }
        sideButton.onTap = { [weak self] action in
            guard let self else { return }
            let text = self.inputBar.text
            self.interactionCoordinator.queueSideAction(["id": action.id, "text": text])
            self.setInputActive(false, animated: true, emit: true)
        }
        tabBar.onSelect = { [weak self] tab, index in
            self?.onEvent?("tabSelected", ["id": tab.id, "index": index])
        }
        inputBar.onTextChanged = { [weak self] text in
            self?.onEvent?("inputTextChanged", ["text": text])
        }
        inputBar.onSubmit = { [weak self] text in
            self?.onEvent?("inputSubmitted", ["text": text])
        }
        inputBar.onPreferredHeightChanged = { [weak self] in
            self?.animateInputHeightChange()
        }
        optionPresenter.onPresentationChanged = { [weak self] active in
            guard let self else { return }
            self.pendingLayoutAnimationDuration = ElysBarMetrics.animationDuration
            self.onEvent?("optionPresentationChanged", ["active": active])
            self.scheduleLayoutChanged(animationDuration: ElysBarMetrics.animationDuration)
        }
        inputBar.onLeadingAccessoryTapped = { [weak self] id, sourceView in
            guard let self else { return }
            if self.optionPresenter.hasItems {
                self.presentInputOptions(from: sourceView)
            } else {
                self.onEvent?("inputAccessoryTapped", ["id": id, "text": self.inputBar.text])
            }
        }
        inputBar.onAccessoryTapped = { [weak self] id in
            guard let self else { return }
            self.onEvent?("inputAccessoryTapped", ["id": id, "text": self.inputBar.text])
        }
    }

    @objc private func blankTapped() {
        guard interactionCoordinator.inputActive else { return }
        inputBar.blur()
    }

    private func presentInputOptions(from sourceView: UIView) {
        let keepFocus = inputBar.isTextInputFocused
        optionPresenter.present(from: sourceView, in: self) { [weak self] item in
            guard let self else { return }
            self.onEvent?("inputOptionTapped", [
                "id": item.id,
                "text": self.inputBar.text
            ])
        }
        inputBar.refocusIfNeeded(keepFocus)
    }

    private func measuredLayout() -> ElysBarLayout {
        referenceTabBar.frame = bounds
        let measured = referenceTabBar.sizeThatFits(bounds.size).height
        let windowSafeBottom = window?.safeAreaInsets.bottom ?? safeAreaInsets.bottom
        return ElysBarMetrics.layout(
            in: bounds,
            safeBottom: windowSafeBottom,
            measuredHeight: measured
        )
    }

    private func configureIcons() {
        let layout = measuredLayout()
        let iconSize = ElysBarMetrics.actionIconSize(for: layout.contentHeight)
        leadingButton.configure(action: config.leadingAction, iconSize: iconSize)
        tabBar.configure(
            tabs: config.tabs,
            selectedId: config.selectedTabId,
            iconSize: ElysBarMetrics.tabIconSize(for: layout.contentHeight),
            isDark: config.isDark
        )
        if let sideAction = config.input.sideAction {
            sideButton.configure(action: sideAction, iconSize: iconSize)
        }
    }

    private func layoutNormal() {
        let layout = measuredLayout()
        let barY = barTopY(for: layout)
        let inset = ElysBarMetrics.sideInset(for: bounds.width)
        let trailingInset = ElysBarMetrics.trailingInset(for: bounds.width)
        let gap = ElysBarMetrics.groupSpacing(for: bounds.width)
        let overlap = ElysBarMetrics.tabBarOverlap(for: bounds.width)
        let controlHeight = layout.contentHeight
        let leadW = controlHeight
        let tabX = inset + leadW + gap - overlap
        tabBar.frame = CGRect(
            x: tabX,
            y: barY,
            width: bounds.width - trailingInset - tabX,
            height: layout.totalHeight
        )
        tabBar.setNeedsLayout()
        tabBar.layoutIfNeeded()
        let itemCenterY = tabBar.itemVisualCenterY() ?? layout.contentRect.midY
        leadingButton.frame = CGRect(
            x: inset,
            y: barY + itemCenterY - controlHeight / 2,
            width: leadW,
            height: controlHeight
        )
        leadingButton.updateCornerRadius(controlHeight / 2)
        configureIcons()
    }

    func layoutInput(_ state: ElysBarRenderState) {
        let inset = min(ElysBarMetrics.inputOuterInset, max(12, bounds.width * 0.07))
        let collapsedHeight = ElysBarMetrics.inputCollapsedHeight
        let expandedWidth = bounds.width - inset * 2
        let height = state.inputExpanded
            ? inputBar.preferredExpandedHeight(for: expandedWidth)
            : collapsedHeight
        let side = collapsedHeight
        let sideGap = state.inputExpanded ? 0 : side + ElysBarMetrics.inputSpacing
        let inputW = max(160, bounds.width - inset * 2 - sideGap)
        let y = state.inputExpanded
            ? max(
                0,
                keyboardTopY(state)
                    - ElysBarMetrics.inputKeyboardGap
                    - height
            )
            : collapsedInputTopY()
        inputBar.frame = CGRect(x: inset, y: y, width: inputW, height: height)
        sideButton.frame = CGRect(x: bounds.width - inset - side, y: y, width: side, height: side)
        inputBar.setExpanded(state.inputExpanded)
        inputBar.updateCornerRadius(
            state.inputExpanded ? ElysBarMetrics.expandedInputCornerRadius : height / 2
        )
        sideButton.updateCornerRadius(side / 2)
        scheduleLayoutChanged(animationDuration: pendingLayoutAnimationDuration)
    }

    private func barTopY(for layout: ElysBarLayout) -> CGFloat {
        guard bounds.height > layout.totalHeight + 1 else { return 0 }
        let keyboard = interactionCoordinator.renderState.keyboard
        let keyboardTop = keyboard.visible ? bounds.height - keyboard.height : bounds.height
        let anchorBottom = min(bounds.height, keyboardTop)
        return max(0, anchorBottom - layout.totalHeight)
    }

    private func collapsedInputTopY() -> CGFloat {
        let layout = measuredLayout()
        let barY = barTopY(for: layout)
        let itemCenterY = tabBar.itemVisualCenterY() ?? layout.contentRect.midY
        return barY + itemCenterY - ElysBarMetrics.inputCollapsedHeight / 2
    }

    private func keyboardTopY(_ state: ElysBarRenderState) -> CGFloat {
        guard state.keyboard.visible else { return bounds.height }
        return bounds.height
    }

}
