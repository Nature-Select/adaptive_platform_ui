import UIKit

enum NativeTabBarBadgeStyle {
    private static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: UIColor.white
    ]

    static func setBadgeCount(_ count: Int?, on item: UITabBarItem) {
        applyFixedTextAttributes(to: item)

        if let count = count, count > 0 {
            item.badgeValue = count > 99 ? "99+" : String(count)
        } else {
            item.badgeValue = nil
        }
    }

    private static func applyFixedTextAttributes(to item: UITabBarItem) {
        item.setBadgeTextAttributes(textAttributes, for: .normal)
        item.setBadgeTextAttributes(textAttributes, for: .selected)
    }
}
