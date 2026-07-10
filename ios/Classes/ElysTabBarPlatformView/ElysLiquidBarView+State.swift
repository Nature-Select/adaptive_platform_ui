import UIKit

@available(iOS 26.0, *)
extension ElysLiquidBarView {
    func setBarHidden(_ hidden: Bool, animated: Bool) {
        guard hidden != barHidden else { return }
        barHidden = hidden
        barHiddenRestoreGeneration += 1
        let generation = barHiddenRestoreGeneration
        if hidden, interactionCoordinator.inputActive {
            inputBar.blur()
        }
        // 隐藏完成后必须 isHidden，否则透明的 rootView 仍会吞掉底部区域的
        // 点击，Flutter 侧内容收不到手势；显示前先解除。
        if !hidden { isHidden = false }
        pendingLayoutAnimationDuration = ElysBarMetrics.animationDuration
        let changes = {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
        guard animated else {
            changes()
            isHidden = hidden
            return
        }
        UIView.animate(
            withDuration: ElysBarMetrics.animationDuration,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: changes
        ) { _ in
            guard generation == self.barHiddenRestoreGeneration else { return }
            if self.barHidden { self.isHidden = true }
        }
    }

    func setInputActive(_ active: Bool, animated: Bool, emit: Bool) {
        let oldState = interactionCoordinator.renderState
        // 状态未变一律直接返回（含 animated=false 的重复调用——setConfig 回写
        // 若穿透到非动画分支，会在 morph 飞行中裸赋值掐断弹簧并在飞行中切
        // glass）；仅初始 apply 放行一次以铺底几何与 glass 静止态。
        guard oldState.inputActive != active || !hasAppliedInitialState else { return }
        hasAppliedInitialState = true
        interactionCoordinator.setInputActive(active)
        if active && !oldState.inputActive {
            inputModeEnteredAt = CACurrentMediaTime()
        }
        let state = interactionCoordinator.renderState
        pendingLayoutAnimationDuration = ElysBarMetrics.morphAnimationDuration
        if active {
            inputBar.finishDismissalAnimation()
            inputBar.setTrailingAccessorySuppressed(false)
        } else {
            optionPresenter.dismiss(animated: animated)
            inputBar.blur()
            inputBar.prepareForDismissalAnimation()
        }
        // 两个方向都立即投递：关闭事件此前排队到动画完成/键盘收起后才发，
        // App 侧切换会滞后 0.3-0.5s+；改为原生动画与业务响应并行。
        if emit { onEvent?("inputModeChanged", ["active": active]) }
        if active { blankTapView.isHidden = false }
        blankTapView.isUserInteractionEnabled = active
        // 交互按终值立即生效，不再整条冻结动画窗口：退场控件的 model alpha
        // 已为 0、UIKit 命中测试天然跳过；入场侧唯一的误触风险（入口→更多
        // 同位互换）由 inputOptionsGraceInterval 栅栏单点兜底。
        setBarControlsInteraction(inputActive: active)
        if animated {
            // 玻璃 effect 只在静止态切换，飞行途中永不过渡；代际守卫保证
            // 被打断动画的过期 completion 整体 no-op（快速反打时前置的
            // setGlassVisible(true) 都是对已开启玻璃的 no-op，安全）。
            // wipe 与胶囊展开同曲线同相位（弹簧进场组）：裁切边始终贴着
            // 胶囊玻璃前沿推进，终点与 side 按钮左缘重合、由其玻璃盖住。
            morphGeneration += 1
            morphInFlight = true
            let generation = morphGeneration
            let exitChanges: () -> Void
            let enterChanges: () -> Void
            if active {
                inputBar.setGlassVisible(true)
                sideButton.setGlassVisible(true)
                exitChanges = { self.applyLeadingRenderState(state) }
                enterChanges = {
                    // 顺序约束：先归位 transform 再布局（frame/bounds 写入
                    // 必须在 identity 下），wipe 与胶囊同一事务推进。
                    self.applyInputControlsRenderState(state)
                    self.layoutInput(state)
                    self.tabWipeProgress = 1
                    self.layoutTabGroup()
                }
            } else {
                leadingButton.setGlassVisible(true)
                // tab 组从被裁剪至 side 按钮位的窗口中展开，先解除 isHidden
                //（窗口宽 62pt 且在 side 按钮玻璃正下方，解除瞬间不可见）。
                tabBar.isHidden = false
                exitChanges = {
                    self.layoutInput(state)
                    self.applyInputControlsRenderState(state)
                }
                enterChanges = {
                    self.applyLeadingRenderState(state)
                    self.tabWipeProgress = 0
                    self.layoutTabGroup()
                }
            }
            UIView.animate(
                withDuration: ElysBarMetrics.morphExitDuration,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseIn],
                animations: exitChanges
            ) { _ in
                guard generation == self.morphGeneration else { return }
                if self.interactionCoordinator.inputActive {
                    self.leadingButton.setGlassVisible(false)
                } else {
                    self.inputBar.setGlassVisible(false)
                    self.sideButton.setGlassVisible(false)
                    if !self.interactionCoordinator.keyboardVisible {
                        self.inputBar.finishDismissalAnimation()
                    }
                }
            }
            UIView.animate(
                withDuration: ElysBarMetrics.morphAnimationDuration,
                delay: 0,
                usingSpringWithDamping: ElysBarMetrics.morphAnimationDamping,
                initialSpringVelocity: ElysBarMetrics.morphInitialVelocity,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: enterChanges
            ) { _ in
                guard generation == self.morphGeneration else { return }
                self.morphInFlight = false
                if self.interactionCoordinator.inputActive {
                    self.tabBar.isHidden = true
                }
                self.blankTapView.isHidden = !active
                self.blankTapView.isUserInteractionEnabled = active
            }
        } else {
            applyInputRenderState(state)
            inputBar.setGlassVisible(active)
            sideButton.setGlassVisible(active)
            leadingButton.setGlassVisible(!active)
            tabBar.isHidden = active
            blankTapView.isHidden = !active
            blankTapView.isUserInteractionEnabled = active
            if !active { inputBar.finishDismissalAnimation() }
        }
    }

    private func setBarControlsInteraction(inputActive: Bool) {
        leadingButton.isUserInteractionEnabled = !inputActive
        tabBar.isUserInteractionEnabled = !inputActive
        inputBar.isUserInteractionEnabled = inputActive
        sideButton.isUserInteractionEnabled = inputActive
    }

    func applyInputRenderState(_ state: ElysBarRenderState) {
        layoutInput(state)
        applyLeadingRenderState(state)
        applyInputControlsRenderState(state)
        // UITabBar 永远不做 alpha/transform/resize：iOS 26 的 UITabBar 私有
        // 液态玻璃在 alpha < 1 时合成退化（全宽底板+错位残影，逐帧实锤），
        // scale 微缩图标又不符合 Apple 官方「原地坍缩成单钮」的形态。tab 侧
        // 用 wrapper 裁剪窗口 wipe（内层零接触），静止态切 isHidden。
        tabWipeProgress = state.tabControlsVisible ? 0 : 1
        layoutTabGroup()
    }

    func applyLeadingRenderState(_ state: ElysBarRenderState) {
        leadingButton.setContentVisible(state.tabControlsVisible)
        leadingButton.restingTransform = state.tabControlsVisible
            ? .identity
            : hiddenLeadingTransform()
    }

    func applyInputControlsRenderState(_ state: ElysBarRenderState) {
        inputBar.setContentVisible(state.inputVisible)
        sideButton.setContentVisible(state.sideButtonVisible)
        blankTapView.alpha = state.inputVisible ? 1 : 0
        inputBar.transform = state.inputVisible ? .identity : hiddenInputTransform()
        sideButton.restingTransform = state.sideButtonVisible
            ? .identity
            : hiddenSideTransform()
    }

    func hiddenLeadingTransform() -> CGAffineTransform {
        CGAffineTransform(translationX: -20, y: 0).scaledBy(x: 0.88, y: 0.88)
    }

    func hiddenInputTransform() -> CGAffineTransform {
        // 收起终点对齐入口按钮正中、缩到与按钮同宽：胶囊被按钮的玻璃完整
        // “吸收”（同一 glass container 渲染为一个 blob），玻璃全程保持开启
        // 也不会有多余的形状滑过按钮。旧终点是向左平移 36% 宽，会飞出按钮
        // 甚至屏幕左缘，退场轨迹整条可见。
        guard inputBar.bounds.width > 1, leadingButton.bounds.width > 1 else {
            return CGAffineTransform(translationX: -22, y: 0).scaledBy(x: 0.28, y: 0.90)
        }
        // 注意：缩放比例不能太极端。tab 静止态下 layoutInput 会在该 transform
        // 生效期间设置 frame（UIKit 未定义行为，bounds 按 1/scale 反推），
        // y 接近 1 时误差可忽略；0.5.17 曾把 y 缩到 0.17，bounds 被放大 6 倍，
        // 开启动画时出现巨型白胶囊从上方弹入。
        let scale = max(0.18, leadingButton.bounds.width / inputBar.bounds.width)
        let shift = leadingButton.center.x - inputBar.center.x
        return CGAffineTransform(translationX: shift, y: 0).scaledBy(x: scale, y: 0.92)
    }

    func hiddenSideTransform() -> CGAffineTransform {
        CGAffineTransform(translationX: 18, y: 0).scaledBy(x: 0.88, y: 0.88)
    }
}

