import UIKit

@available(iOS 26.0, *)
extension ElysLiquidBarView {
    func setInputActive(_ active: Bool, animated: Bool, emit: Bool) {
        let oldState = interactionCoordinator.renderState
        guard oldState.inputActive != active || !animated else { return }
        interactionCoordinator.setInputActive(active, emitCloseEvent: emit)
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
        leadingButton.isUserInteractionEnabled = !active
        tabBar.isUserInteractionEnabled = !active
        inputBar.isUserInteractionEnabled = active
        sideButton.isUserInteractionEnabled = active
        let changes = {
            self.applyInputRenderState(state)
        }
        if animated {
            UIView.animate(
                withDuration: ElysBarMetrics.animationDuration,
                delay: 0,
                usingSpringWithDamping: ElysBarMetrics.animationDamping,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: changes
            ) { _ in
                self.blankTapView.isHidden = !active
                self.blankTapView.isUserInteractionEnabled = active
                if !active && !self.interactionCoordinator.keyboardVisible {
                    self.inputBar.finishDismissalAnimation()
                    self.flushPendingCloseEvents()
                }
            }
        } else {
            changes()
            blankTapView.isHidden = !active
            blankTapView.isUserInteractionEnabled = active
            if !active { inputBar.finishDismissalAnimation() }
            if !active { flushPendingCloseEvents() }
        }
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
