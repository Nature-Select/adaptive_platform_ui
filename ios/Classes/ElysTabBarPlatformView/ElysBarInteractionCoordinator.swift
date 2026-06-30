import UIKit

@available(iOS 26.0, *)
enum ElysBarInteractionMode {
    case tabBar
    case inputCollapsed
    case inputExpandedKeyboard
}

@available(iOS 26.0, *)
struct ElysBarKeyboardSnapshot {
    let visible: Bool
    let height: CGFloat
    let topInWindow: CGFloat?

    static let hidden = ElysBarKeyboardSnapshot(visible: false, height: 0, topInWindow: nil)
}

@available(iOS 26.0, *)
struct ElysBarRenderState {
    let mode: ElysBarInteractionMode
    let keyboard: ElysBarKeyboardSnapshot

    var inputActive: Bool { mode != .tabBar }
    var inputExpanded: Bool { mode == .inputExpandedKeyboard }
    var tabControlsVisible: Bool { mode == .tabBar }
    var inputVisible: Bool { mode != .tabBar }
    var sideButtonVisible: Bool { mode == .inputCollapsed }
}

@available(iOS 26.0, *)
final class ElysBarInteractionCoordinator {
    private(set) var mode: ElysBarInteractionMode = .tabBar
    private(set) var keyboard: ElysBarKeyboardSnapshot = .hidden
    private var pendingInputClosedEvent = false
    private var pendingSideActionPayload: [String: Any]?

    var renderState: ElysBarRenderState {
        ElysBarRenderState(mode: mode, keyboard: keyboard)
    }

    var inputActive: Bool { renderState.inputActive }
    var keyboardVisible: Bool { keyboard.visible }

    func setInputActive(_ active: Bool, emitCloseEvent: Bool) {
        if active {
            mode = keyboard.visible ? .inputExpandedKeyboard : .inputCollapsed
            pendingInputClosedEvent = false
            pendingSideActionPayload = nil
        } else {
            mode = .tabBar
            if emitCloseEvent {
                pendingInputClosedEvent = true
            }
        }
    }

    func setKeyboard(
        visible: Bool,
        height: CGFloat,
        topInWindow: CGFloat?
    ) {
        keyboard = visible
            ? ElysBarKeyboardSnapshot(visible: true, height: height, topInWindow: topInWindow)
            : .hidden
        guard inputActive else { return }
        mode = visible ? .inputExpandedKeyboard : .inputCollapsed
    }

    func keyboardDidHideCleanup() {
        keyboard = .hidden
        if mode == .inputExpandedKeyboard {
            mode = .inputCollapsed
        }
    }

    func queueSideAction(_ payload: [String: Any]) {
        pendingSideActionPayload = payload
    }

    func takePendingEvents() -> [(String, [String: Any])] {
        var events: [(String, [String: Any])] = []
        if pendingInputClosedEvent {
            pendingInputClosedEvent = false
            events.append(("inputModeChanged", ["active": false]))
        }
        if let payload = pendingSideActionPayload {
            pendingSideActionPayload = nil
            events.append(("inputSideActionTapped", payload))
        }
        return events
    }
}
