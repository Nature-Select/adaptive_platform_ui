import UIKit

@available(iOS 26.0, *)
struct ElysInputOptionConfig {
    let id: String
    let icon: String
    let title: String
    let enabled: Bool
    let accessibilityLabel: String?

    init?(dict: [String: Any]?) {
        guard let dict,
              let id = dict["id"] as? String,
              let icon = dict["icon"] as? String,
              let title = dict["title"] as? String else { return nil }
        self.id = id
        self.icon = icon
        self.title = title
        self.enabled = (dict["enabled"] as? NSNumber)?.boolValue ?? true
        self.accessibilityLabel = dict["accessibilityLabel"] as? String
    }
}
