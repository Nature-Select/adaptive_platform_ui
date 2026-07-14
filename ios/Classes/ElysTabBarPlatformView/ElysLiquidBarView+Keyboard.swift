import UIKit

@available(iOS 26.0, *)
extension ElysLiquidBarView {
    func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameChanged(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidHide(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }

    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let window else { return }
        let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue ?? .zero
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?
            .doubleValue ?? 0
        let animationOptions = keyboardAnimationOptions(from: notification)
        let keyboardFrame = window.convert(frame, from: nil)
        let visible = keyboardFrame.minY < window.bounds.maxY && keyboardFrame.maxY > 0
        let keyboardTop = visible ? max(0, min(window.bounds.maxY, keyboardFrame.minY)) : window.bounds.maxY
        let height = visible ? max(0, window.bounds.maxY - keyboardTop) : 0
        interactionCoordinator.setKeyboard(
            visible: visible,
            height: height,
            topInWindow: visible ? keyboardTop : nil
        )
        optionPresenter.updateKeyboard(
            topInWindow: visible ? keyboardTop : nil,
            window: window
        )
        pendingLayoutAnimationDuration = max(0.18, duration)
        let state = interactionCoordinator.renderState
        if visible {
            startKeyboardTracking(duration: duration)
        } else {
            stopKeyboardTracking()
        }
        animateKeyboardRenderState(
            state,
            duration: duration,
            options: animationOptions
        )
        onEvent?("keyboardFrameChanged", [
            "height": height,
            "duration": duration,
            "visible": visible
        ])
    }

    @objc private func keyboardDidHide(_ notification: Notification) {
        stopKeyboardTracking()
        interactionCoordinator.keyboardDidHideCleanup()
        applyInputRenderState(interactionCoordinator.renderState)
        optionPresenter.updateKeyboard(topInWindow: nil, window: window)
        if !interactionCoordinator.inputActive {
            inputBar.finishDismissalAnimation()
        }
    }

    private func animateKeyboardRenderState(
        _ state: ElysBarRenderState,
        duration: TimeInterval,
        options: UIView.AnimationOptions
    ) {
        let changes = {
            self.applyInputRenderState(state)
        }
        let completion: (Bool) -> Void = { _ in
            self.applyInputRenderState(self.interactionCoordinator.renderState)
        }
        UIView.animate(
            withDuration: max(0.18, duration),
            delay: 0,
            options: options,
            animations: changes,
            completion: completion
        )
    }

    private func keyboardAnimationOptions(from notification: Notification) -> UIView.AnimationOptions {
        let curve = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?
            .uintValue ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        return [
            UIView.AnimationOptions(rawValue: curve << 16),
            .allowUserInteraction,
            .beginFromCurrentState
        ]
    }

    private func startKeyboardTracking(duration: TimeInterval) {
        stopKeyboardTracking()
        let link = CADisplayLink(target: self, selector: #selector(keyboardDisplayTick))
        keyboardDisplayLink = link
        link.add(to: .main, forMode: .common)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.18, duration) + 0.08) { [weak self] in
            self?.stopKeyboardTracking()
            guard let self else { return }
            self.layoutInput(self.interactionCoordinator.renderState)
        }
    }

    private func stopKeyboardTracking() {
        keyboardDisplayLink?.invalidate()
        keyboardDisplayLink = nil
    }

    @objc private func keyboardDisplayTick() {
        layoutInput(interactionCoordinator.renderState)
    }

    func animateInputHeightChange() {
        let state = interactionCoordinator.renderState
        guard state.inputActive, state.inputExpanded else { return }
        pendingLayoutAnimationDuration = ElysBarMetrics.animationDuration
        UIView.animate(
            withDuration: ElysBarMetrics.animationDuration,
            delay: 0,
            usingSpringWithDamping: ElysBarMetrics.animationDamping,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.layoutInput(self.interactionCoordinator.renderState)
            }
        )
    }
}
