import UIKit

@available(iOS 26.0, *)
struct ElysBarLayout {
    let totalHeight: CGFloat
    let safeBottom: CGFloat
    let contentRect: CGRect

    var contentHeight: CGFloat { contentRect.height }
    var contentCenterY: CGFloat { contentRect.midY }
}

@available(iOS 26.0, *)
enum ElysBarMetrics {
    static let fallbackTotalHeight: CGFloat = 83
    static let fallbackContentHeight: CGFloat = 62
    static let sideInset: CGFloat = 20
    static let compactSideInset: CGFloat = 20
    static let trailingInset: CGFloat = -4
    static let compactTrailingInset: CGFloat = -4
    static let groupSpacing: CGFloat = -8
    static let compactGroupSpacing: CGFloat = -8
    static let tabBarOverlap: CGFloat = 0
    static let compactTabBarOverlap: CGFloat = 0
    static let inputOuterInset: CGFloat = 27
    static let inputSpacing: CGFloat = 9
    static let inputKeyboardGap: CGFloat = 2
    static let inputCollapsedHeight: CGFloat = 62
    static let expandedTextHorizontalInset: CGFloat = 15
    static let expandedTextTopInset: CGFloat = 18
    static let expandedTextBottomInset: CGFloat = 66
    static let inputLeadingAccessorySize: CGFloat = 22
    static let inputCompactLeadingAccessorySize: CGFloat = 22
    static let inputTrailingAccessorySize: CGFloat = 36
    static let inputTrailingBackgroundSize: CGFloat = 36
    static let inputLeadingIconMaxSize: CGFloat = 22
    static let inputCompactLeadingIconMaxSize: CGFloat = 22
    static let inputTrailingIconMaxSize: CGFloat = 27
    static let inputAccessoryOuterInset: CGFloat = 18
    static let inputCompactLeadingAccessoryOuterInset: CGFloat = 12
    static let inputExpandedLeadingAccessoryOuterInset: CGFloat = 12
    static let inputExpandedLeadingAccessoryBottomInset: CGFloat = 20
    static let inputTrailingAccessoryOuterInset: CGFloat = 13
    static let inputAccessoryTextGap: CGFloat = 8
    static let inputAccessoryHitSlop: CGFloat = 11
    static let inputFontSize: CGFloat = 15
    static let expandedInputCornerRadius: CGFloat = 31
    static let glassMergeSpacing: CGFloat = 14
    static let animationDuration: TimeInterval = 0.32
    static let animationDamping: CGFloat = 0.86
    static let selectedPillAlpha: CGFloat = 0.55
    static let darkSelectedPillAlpha: CGFloat = 0.18

    static func sideInset(for width: CGFloat) -> CGFloat {
        width < 360 ? compactSideInset : sideInset
    }

    static func groupSpacing(for width: CGFloat) -> CGFloat {
        width < 360 ? compactGroupSpacing : groupSpacing
    }

    static func trailingInset(for width: CGFloat) -> CGFloat {
        width < 360 ? compactTrailingInset : trailingInset
    }

    static func tabBarOverlap(for width: CGFloat) -> CGFloat {
        width < 360 ? compactTabBarOverlap : tabBarOverlap
    }

    static func actionIconSize(for height: CGFloat) -> CGFloat {
        tabIconSize(for: height)
    }

    static func tabIconSize(for height: CGFloat) -> CGFloat {
        min(36, height * 0.60)
    }

    static func layout(in bounds: CGRect, safeBottom: CGFloat, measuredHeight: CGFloat) -> ElysBarLayout {
        let total = max(measuredHeight, fallbackTotalHeight)
        _ = safeBottom
        let bottom = max(0, total - fallbackContentHeight)
        let contentHeight = max(44, min(fallbackContentHeight, total - bottom))
        let contentRect = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: contentHeight
        )
        return ElysBarLayout(totalHeight: total, safeBottom: bottom, contentRect: contentRect)
    }
}

@available(iOS 26.0, *)
final class ElysPassthroughGlassContainerView: UIVisualEffectView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView === self || hitView === contentView {
            return nil
        }
        return hitView
    }
}
