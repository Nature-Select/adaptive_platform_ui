import UIKit

@available(iOS 26.0, *)
struct ElysActionConfig {
    let id: String
    let icon: String
    let badgeCount: Int?
    let accessibilityLabel: String?

    init?(dict: [String: Any]?) {
        guard let dict,
              let id = dict["id"] as? String,
              let icon = dict["icon"] as? String else { return nil }
        self.id = id
        self.icon = icon
        self.badgeCount = (dict["badgeCount"] as? NSNumber)?.intValue
        self.accessibilityLabel = dict["accessibilityLabel"] as? String
    }
}

@available(iOS 26.0, *)
struct ElysTabConfig {
    let id: String
    let icon: String
    let selectedIcon: String?
    let badgeCount: Int?
    let accessibilityLabel: String?

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let icon = dict["icon"] as? String else { return nil }
        self.id = id
        self.icon = icon
        self.selectedIcon = dict["selectedIcon"] as? String
        self.badgeCount = (dict["badgeCount"] as? NSNumber)?.intValue
        self.accessibilityLabel = dict["accessibilityLabel"] as? String
    }
}

@available(iOS 26.0, *)
struct ElysInputConfig {
    let text: String
    let placeholder: String
    let sideAction: ElysActionConfig?
    let leadingAction: ElysActionConfig?
    let collapsedTrailingAction: ElysActionConfig?
    let expandedTrailingAction: ElysActionConfig?
    let optionItems: [ElysInputOptionConfig]

    init(dict: [String: Any]?) {
        self.text = dict?["text"] as? String ?? ""
        self.placeholder = dict?["placeholder"] as? String ?? ""
        self.sideAction = ElysActionConfig(dict: dict?["sideAction"] as? [String: Any])
        self.leadingAction = ElysActionConfig(dict: dict?["leadingAction"] as? [String: Any])
        self.collapsedTrailingAction = ElysActionConfig(
            dict: dict?["collapsedTrailingAction"] as? [String: Any]
        )
        self.expandedTrailingAction = ElysActionConfig(
            dict: dict?["expandedTrailingAction"] as? [String: Any]
        )
        let optionDicts = dict?["optionItems"] as? [[String: Any]] ?? []
        self.optionItems = optionDicts.compactMap(ElysInputOptionConfig.init)
    }
}

@available(iOS 26.0, *)
struct ElysBarConfig {
    let leadingAction: ElysActionConfig
    let tabs: [ElysTabConfig]
    let selectedTabId: String
    let inputActive: Bool
    let input: ElysInputConfig
    let isDark: Bool

    init?(args: Any?) {
        guard let dict = args as? [String: Any],
              let leading = ElysActionConfig(
                dict: dict["leadingAction"] as? [String: Any]
              ) else { return nil }
        let tabDicts = dict["tabs"] as? [[String: Any]] ?? []
        self.leadingAction = leading
        self.tabs = tabDicts.compactMap(ElysTabConfig.init)
        self.selectedTabId = dict["selectedTabId"] as? String ?? ""
        self.inputActive = (dict["inputActive"] as? NSNumber)?.boolValue ?? false
        self.input = ElysInputConfig(dict: dict["input"] as? [String: Any])
        self.isDark = (dict["isDark"] as? NSNumber)?.boolValue ?? false
    }
}
