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

    var renderState: ElysBarRenderState {
        ElysBarRenderState(mode: mode, keyboard: keyboard)
    }

    var inputActive: Bool { renderState.inputActive }
    var keyboardVisible: Bool { keyboard.visible }

    func setInputActive(_ active: Bool) {
        mode = active
            ? (keyboard.visible ? .inputExpandedKeyboard : .inputCollapsed)
            : .tabBar
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
}
