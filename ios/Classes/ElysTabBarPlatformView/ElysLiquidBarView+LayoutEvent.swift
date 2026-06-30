import UIKit

@available(iOS 26.0, *)
extension ElysLiquidBarView {
    func scheduleLayoutChanged(animationDuration: TimeInterval) {
        pendingLayoutAnimationDuration = animationDuration
        guard !layoutEmitScheduled else { return }
        layoutEmitScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.emitLayoutChangedIfNeeded()
        }
    }

    private func emitLayoutChangedIfNeeded() {
        layoutEmitScheduled = false
        let payload = layoutPayload(animationDuration: pendingLayoutAnimationDuration)
        pendingLayoutAnimationDuration = ElysBarMetrics.animationDuration
        let signature = layoutSignature(payload)
        guard signature != lastLayoutPayloadSignature else { return }
        lastLayoutPayloadSignature = signature
        onEvent?("layoutChanged", payload)
    }

    private func layoutPayload(animationDuration: TimeInterval) -> [String: Any] {
        let state = interactionCoordinator.renderState
        return [
            "mode": modeName(state.mode),
            "platformWidth": Double(bounds.width),
            "platformHeight": Double(bounds.height),
            "inputFrame": rectPayload(inputBar.frame),
            "keyboardHeight": Double(state.keyboard.height),
            "keyboardVisible": state.keyboard.visible,
            "animationDuration": animationDuration
        ]
    }

    private func rectPayload(_ rect: CGRect) -> [String: Double] {
        [
            "x": Double(rect.minX),
            "y": Double(rect.minY),
            "width": Double(rect.width),
            "height": Double(rect.height)
        ]
    }

    private func modeName(_ mode: ElysBarInteractionMode) -> String {
        switch mode {
        case .tabBar:
            return "tabBar"
        case .inputCollapsed:
            return "inputCollapsed"
        case .inputExpandedKeyboard:
            return "inputExpandedKeyboard"
        }
    }

    private func layoutSignature(_ payload: [String: Any]) -> String {
        let input = payload["inputFrame"] as? [String: Double] ?? [:]
        let rounded = input
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(Int(($0.value * 10).rounded()))" }
            .joined(separator: ",")
        return [
            payload["mode"] as? String ?? "",
            "\(Int(((payload["platformWidth"] as? Double ?? 0) * 10).rounded()))",
            "\(Int(((payload["platformHeight"] as? Double ?? 0) * 10).rounded()))",
            rounded,
            "\(payload["keyboardVisible"] as? Bool ?? false)",
            "\(Int(((payload["keyboardHeight"] as? Double ?? 0) * 10).rounded()))"
        ].joined(separator: "|")
    }
}
