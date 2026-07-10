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
        interactionCoordinator.setInputActive(active, emitCloseEvent: emit)
        if active && !oldState.inputActive {
            inputModeEnteredAt = CACurrentMediaTime()
        }
        let state = interactionCoordinator.renderState
        pendingLayoutAnimationDuration = ElysBarMetrics.animationDuration
        if active {
            inputBar.finishDismissalAnimation()
            inputBar.setTrailingAccessorySuppressed(false)
            if emit { onEvent?("inputModeChanged", ["active": true]) }
        } else {
            optionPresenter.dismiss(animated: animated)
            inputBar.blur()
            inputBar.prepareForDismissalAnimation()
        }
        if active { blankTapView.isHidden = false }
        blankTapView.isUserInteractionEnabled = active
        barControlsRestoreGeneration += 1
        let generation = barControlsRestoreGeneration
        let changes = {
            self.applyInputRenderState(state)
        }
        if animated {
            // 形态切换期间左下角入口按钮与输入“更多”按钮在同一位置互换，
            // UIKit 命中测试按 model layer 终值生效；若不冻结命中，动画播放
            // 期间的连点会直接命中新形态控件（例如误弹输入更多菜单）。
            setBarControlsInteraction(inputActive: active, morphing: true)
            UIView.animate(
                withDuration: ElysBarMetrics.animationDuration,
                delay: 0,
                usingSpringWithDamping: ElysBarMetrics.animationDamping,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: changes
            ) { _ in
                if generation == self.barControlsRestoreGeneration {
                    self.setBarControlsInteraction(
                        inputActive: self.interactionCoordinator.inputActive,
                        morphing: false
                    )
                }
                self.blankTapView.isHidden = !active
                self.blankTapView.isUserInteractionEnabled = active
                if !active && !self.interactionCoordinator.keyboardVisible {
                    self.inputBar.finishDismissalAnimation()
                    self.flushPendingCloseEvents()
                }
            }
        } else {
            setBarControlsInteraction(inputActive: active, morphing: false)
            changes()
            blankTapView.isHidden = !active
            blankTapView.isUserInteractionEnabled = active
            if !active { inputBar.finishDismissalAnimation() }
            if !active { flushPendingCloseEvents() }
        }
    }

    private func setBarControlsInteraction(inputActive: Bool, morphing: Bool) {
        leadingButton.isUserInteractionEnabled = !morphing && !inputActive
        tabBar.isUserInteractionEnabled = !morphing && !inputActive
        inputBar.isUserInteractionEnabled = !morphing && inputActive
        sideButton.isUserInteractionEnabled = !morphing && inputActive
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
