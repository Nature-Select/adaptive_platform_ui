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
    private var iconConfigGeneration = 0
    private var appliedIconGeneration = -1
    private var appliedIconContentHeight: CGFloat = -1
    var barHidden = false
    var barHiddenRestoreGeneration = 0
    var inputModeEnteredAt: CFTimeInterval = 0
    // tab 组擦除进度（0=全显，1=收进 side 按钮位）。单一事实源：布局路径
    // （layoutNormal）从它幂等推导 wrapper 几何，动画块内改它后重放布局，
    // 任何动画块外的布局脉冲都只是模型 no-op，不会扰动 additive 动画。
    var tabWipeProgress: CGFloat = 0
    // morph 代际：过期动画 completion 一律 no-op（照抄 barHidden 的模式）。
    var morphGeneration = 0
    var morphInFlight = false
    var hasAppliedInitialState = false
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
        iconConfigGeneration += 1
        configureIconsIfNeeded()
        inputBar.configure(config.input)
        optionPresenter.configure(items: config.input.optionItems)
        setInputActive(config.inputActive, animated: animated, emit: false)
        setNeedsLayout()
    }

    func setSelectedTab(_ id: String) {
        guard config.selectedTabId != id else { return }
        config.selectedTabId = id
        tabBar.setSelected(id: id)
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

    func updateInputPrefix(_ prefix: ElysInputPrefixConfig?) {
        inputBar.setPrefix(prefix)
    }

    func focusInput() {
        // 隐藏态下聚焦会弹出键盘却看不到输入框，且用户无从关闭，直接忽略。
        guard !barHidden else { return }
        // 先保证几何就绪再起 morph——动画启动后再强制布局属于动画块外的
        // 裸赋值，会掐断进场弹簧。
        setNeedsLayout(); layoutIfNeeded()
        if !interactionCoordinator.inputActive {
            setInputActive(true, animated: true, emit: true)
        }
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
        // tab wrapper 在玻璃容器之下：输入胶囊展开时其玻璃从上方扫过被擦除
        // 中的 tab 胶囊，裁切边始终藏在胶囊玻璃前沿之后。
        [referenceTabBar, blankTapView, tabBar, glassContainerView].forEach {
            addSubview($0)
        }
        [leadingButton, inputBar, sideButton].forEach {
            glassContainerView.contentView.addSubview($0)
        }
        inputBar.setContentVisible(false)
        inputBar.setGlassVisible(false)
        sideButton.setContentVisible(false)
        sideButton.setGlassVisible(false)
        inputBar.transform = hiddenInputTransform()
        sideButton.restingTransform = hiddenSideTransform()
        leadingButton.onTap = { [weak self] action in
            guard let self else { return }
            self.setInputActive(true, animated: true, emit: true)
            self.onEvent?("leadingActionTapped", ["id": action.id])
        }
        sideButton.onTap = { [weak self] action in
            guard let self else { return }
            let text = self.inputBar.text
            self.setInputActive(false, animated: true, emit: true)
            self.onEvent?("inputSideActionTapped", ["id": action.id, "text": text])
        }
        tabBar.onSelect = { [weak self] tab, index in
            self?.onEvent?("tabSelected", ["id": tab.id, "index": index])
        }
        inputBar.onTextChanged = { [weak self] text in
            self?.onEvent?("inputTextChanged", ["text": text])
        }
        inputBar.onPrefixDeleted = { [weak self] id in
            self?.onEvent?("inputPrefixDeleted", ["id": id])
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
            // 更多按钮与 tab 态入口按钮同位同型互换：非输入态一律不响应（显式
            // 不变量），刚进输入态的栅栏期内视为对旧入口按钮的重复误触，直接
            // 吞掉——#13 的 0.32s 动画冻结盖不住秒级的人因重复点击。
            guard self.interactionCoordinator.inputActive,
                  CACurrentMediaTime() - self.inputModeEnteredAt
                      > ElysBarMetrics.inputOptionsGraceInterval else { return }
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

    // 图标重配涉及磁盘读图 + UITabBarItem 重建，只允许在配置代际或实测高度
    // 变化时执行；layoutSubviews 每帧都会走到这里（键盘/形态动画期间尤甚）。
    private func configureIconsIfNeeded() {
        let layout = measuredLayout()
        guard appliedIconGeneration != iconConfigGeneration
            || appliedIconContentHeight != layout.contentHeight else { return }
        appliedIconGeneration = iconConfigGeneration
        appliedIconContentHeight = layout.contentHeight
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

    // 布局一律走 center + bounds：transform 非 identity 时设 frame 是 UIKit
    // 未定义行为，bounds 会被按逆变换反推放大（日志实测：吸收态胶囊 bounds
    // 被撑到 1066pt），与动画撞上时渲染成数倍屏宽的玻璃板。
    private func place(_ view: UIView, _ frame: CGRect) {
        view.bounds = CGRect(origin: .zero, size: frame.size)
        view.center = CGPoint(x: frame.midX, y: frame.midY)
    }

    private func layoutNormal() {
        configureIconsIfNeeded()
        layoutTabGroup()
    }

    // tab 组几何单点合成：y 含 setBarHidden 位移、x/width 含 wipe 进度，
    // 每次调用全量重算（自然宽度不跨帧缓存，旋转/分屏安全）。
    func layoutTabGroup() {
        let layout = measuredLayout()
        let barY = barTopY(for: layout)
        let inset = ElysBarMetrics.sideInset(for: bounds.width)
        let trailingInset = ElysBarMetrics.trailingInset(for: bounds.width)
        let gap = ElysBarMetrics.groupSpacing(for: bounds.width)
        let overlap = ElysBarMetrics.tabBarOverlap(for: bounds.width)
        let controlHeight = layout.contentHeight
        let leadW = controlHeight
        let tabX = inset + leadW + gap - overlap
        let natural = CGRect(
            x: tabX,
            y: barY,
            width: bounds.width - trailingInset - tabX,
            height: layout.totalHeight
        )
        // 坍缩终点：窗口左缘 = 输入胶囊终态右缘（与胶囊展开同曲线同事务时，
        // 裁切边全程严格躲在玻璃前沿之后、t=1 恰好重合，不露一帧）；窗口右缘
        // = side 按钮右缘，残留 tail 被 side 按钮玻璃与 merge 覆盖，静止态由
        // isHidden 收尾。（Apple 官方形态：胶囊原地收拢成单钮，图标不缩放。）
        let sideInset = min(ElysBarMetrics.inputOuterInset, max(12, bounds.width * 0.07))
        let side = ElysBarMetrics.inputCollapsedHeight
        let sideGap = side + ElysBarMetrics.inputSpacing
        let pillRightEnd = sideInset + max(160, bounds.width - sideInset * 2 - sideGap)
        let target = CGRect(
            x: pillRightEnd,
            y: natural.minY,
            width: max(1, (bounds.width - sideInset) - pillRightEnd),
            height: natural.height
        )
        tabBar.applyWipe(natural: natural, target: target, progress: tabWipeProgress)
        tabBar.setNeedsLayout()
        tabBar.layoutIfNeeded()
        let itemCenterY = tabBar.itemVisualCenterY() ?? layout.contentRect.midY
        place(leadingButton, CGRect(
            x: inset,
            y: barY + itemCenterY - controlHeight / 2,
            width: leadW,
            height: controlHeight
        ))
        leadingButton.updateCornerRadius(controlHeight / 2)
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
            ) + hiddenBarShift(totalHeight: measuredLayout().totalHeight)
            : collapsedInputTopY()
        place(inputBar, CGRect(x: inset, y: y, width: inputW, height: height))
        place(sideButton, CGRect(x: bounds.width - inset - side, y: y, width: side, height: side))
        inputBar.setExpanded(state.inputExpanded)
        inputBar.updateCornerRadius(
            state.inputExpanded ? ElysBarMetrics.expandedInputCornerRadius : height / 2
        )
        sideButton.updateCornerRadius(side / 2)
        scheduleLayoutChanged(animationDuration: pendingLayoutAnimationDuration)
    }

    // 隐藏 = 整条 bar 平移出平台视图底边（多 hiddenBarOverflow 余量盖住玻璃
    // 高光），平台视图自身尺寸不变，Flutter 侧不会产生任何布局连锁。
    private func hiddenBarShift(totalHeight: CGFloat) -> CGFloat {
        barHidden ? totalHeight + ElysBarMetrics.hiddenBarOverflow : 0
    }

    private func barTopY(for layout: ElysBarLayout) -> CGFloat {
        let hiddenShift = hiddenBarShift(totalHeight: layout.totalHeight)
        guard bounds.height > layout.totalHeight + 1 else { return hiddenShift }
        let keyboard = interactionCoordinator.renderState.keyboard
        // 只有本 bar 自己的输入态才随键盘抬升；页面上其他输入框（Flutter 侧）
        // 弹键盘时 bar 保持原位，避免入口按钮漂移到内容区造成误触。
        let liftsAboveKeyboard = keyboard.visible && interactionCoordinator.inputActive
        let keyboardTop = liftsAboveKeyboard ? bounds.height - keyboard.height : bounds.height
        let anchorBottom = min(bounds.height, keyboardTop)
        return max(0, anchorBottom - layout.totalHeight) + hiddenShift
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
