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
        guard oldState.inputActive != active || !animated else { return }
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
        let changes = {
            self.applyInputRenderState(state)
        }
        if animated {
            // 玻璃 effect 只在静止态切换，飞行途中永不过渡（消融/物化过渡会
            // 把玻璃底板整块渲染出来）：进场元素动画前无感开启（起点被覆盖或
            // 即将弹出），退场元素保持开启带着玻璃退场，completion 按当前状态
            // 收尾关闭。
            if active {
                inputBar.setGlassVisible(true)
                sideButton.setGlassVisible(true)
            } else {
                leadingButton.setGlassVisible(true)
            }
            UIView.animate(
                withDuration: ElysBarMetrics.morphAnimationDuration,
                delay: 0,
                usingSpringWithDamping: ElysBarMetrics.morphAnimationDamping,
                initialSpringVelocity: ElysBarMetrics.morphInitialVelocity,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: changes
            ) { _ in
                let inputActiveNow = self.interactionCoordinator.inputActive
                self.inputBar.setGlassVisible(inputActiveNow)
                self.sideButton.setGlassVisible(inputActiveNow)
                self.leadingButton.setGlassVisible(!inputActiveNow)
                self.blankTapView.isHidden = !active
                self.blankTapView.isUserInteractionEnabled = active
                if !active && !self.interactionCoordinator.keyboardVisible {
                    self.inputBar.finishDismissalAnimation()
                }
            }
        } else {
            changes()
            inputBar.setGlassVisible(active)
            sideButton.setGlassVisible(active)
            leadingButton.setGlassVisible(!active)
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
        leadingButton.setContentVisible(state.tabControlsVisible)
        tabBar.alpha = state.tabControlsVisible ? 1 : 0
        inputBar.setContentVisible(state.inputVisible)
        sideButton.setContentVisible(state.sideButtonVisible)
        blankTapView.alpha = state.inputVisible ? 1 : 0
        leadingButton.transform = state.tabControlsVisible ? .identity : hiddenLeadingTransform()
        tabBar.transform = state.tabControlsVisible ? .identity : hiddenTabTransform()
        inputBar.transform = state.inputVisible ? .identity : hiddenInputTransform()
        sideButton.transform = state.sideButtonVisible ? .identity : hiddenSideTransform()
    }

    func hiddenLeadingTransform() -> CGAffineTransform {
        CGAffineTransform(translationX: -20, y: 0).scaledBy(x: 0.88, y: 0.88)
    }

    func hiddenTabTransform() -> CGAffineTransform {
        CGAffineTransform(translationX: 28, y: 0).scaledBy(x: 0.96, y: 0.96)
    }

    func hiddenInputTransform() -> CGAffineTransform {
        // 收起终点对齐入口按钮正中、缩到与按钮同宽：胶囊被按钮的玻璃完整
        // “吸收”（同一 glass container 渲染为一个 blob），玻璃全程保持开启
        // 也不会有多余的形状滑过按钮。旧终点是向左平移 36% 宽，会飞出按钮
        // 甚至屏幕左缘，退场轨迹整条可见。
        guard inputBar.bounds.width > 1, leadingButton.bounds.width > 1 else {
            return CGAffineTransform(translationX: -22, y: 0).scaledBy(x: 0.28, y: 0.90)
        }
        let scale = max(0.18, leadingButton.bounds.width / inputBar.bounds.width)
        let shift = leadingButton.center.x - inputBar.center.x
        return CGAffineTransform(translationX: shift, y: 0).scaledBy(x: scale, y: 0.92)
    }

    func hiddenSideTransform() -> CGAffineTransform {
        CGAffineTransform(translationX: 18, y: 0).scaledBy(x: 0.88, y: 0.88)
    }
}
