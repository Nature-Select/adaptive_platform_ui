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
            UIView.animate(
                withDuration: ElysBarMetrics.morphAnimationDuration,
                delay: 0,
                usingSpringWithDamping: ElysBarMetrics.morphAnimationDamping,
                initialSpringVelocity: ElysBarMetrics.morphInitialVelocity,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: changes
            ) { _ in
                self.blankTapView.isHidden = !active
                self.blankTapView.isUserInteractionEnabled = active
                if !active && !self.interactionCoordinator.keyboardVisible {
                    self.inputBar.finishDismissalAnimation()
                }
            }
        } else {
            changes()
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
        leadingButton.alpha = state.tabControlsVisible ? 1 : 0
        tabBar.alpha = state.tabControlsVisible ? 1 : 0
        inputBar.alpha = state.inputVisible ? 1 : 0
        sideButton.alpha = state.sideButtonVisible ? 1 : 0
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
        let shift = -max(22, inputBar.bounds.width * 0.36)
        return CGAffineTransform(translationX: shift, y: 0).scaledBy(x: 0.28, y: 0.90)
    }

    func hiddenSideTransform() -> CGAffineTransform {
        CGAffineTransform(translationX: 18, y: 0).scaledBy(x: 0.88, y: 0.88)
    }
}
