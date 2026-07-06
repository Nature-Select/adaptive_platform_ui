import UIKit

@available(iOS 26.0, *)
extension ElysInputBarView {
    func setPrefix(_ prefix: ElysInputPrefixConfig?) {
        guard !isSamePrefix(inputPrefix, prefix) else { return }
        inputPrefix = prefix
        renderInputText()
        notifyPreferredHeightChanged()
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText replacement: String
    ) -> Bool {
        guard !isApplyingTextStorage else { return true }
        guard rangeTouchesPrefix(range) else { return true }
        applyPrefixReplacement(in: range, replacement: replacement)
        return false
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isApplyingTextStorage else { return }
        let prefixLength = currentPrefixLength()
        guard prefixLength > 0, textView.selectedRange.location < prefixLength else { return }
        textView.selectedRange = NSRange(location: prefixLength, length: 0)
    }

    fileprivate func applyPrefixReplacement(in range: NSRange, replacement: String) {
        let prefixLength = currentPrefixLength()
        let body = inputText as NSString
        let deletedPrefix = inputPrefix
        let affectedBodyLength = max(0, min(body.length, range.upperBound - prefixLength))
        let updated = body.replacingCharacters(
            in: NSRange(location: 0, length: affectedBodyLength),
            with: replacement
        )
        inputPrefix = nil
        inputText = updated
        renderInputText(cursorBodyOffset: (replacement as NSString).length)
        notifyPreferredHeightChanged()
        if let deletedPrefix { onPrefixDeleted?(deletedPrefix.id) }
        onTextChanged?(inputText)
    }

    func renderInputText(cursorBodyOffset requestedOffset: Int? = nil) {
        let bodyOffset = requestedOffset ?? currentBodySelectionOffset()
        let prefix = prefixAttributedString()
        let body = inputText.isEmpty && prefix == nil
            ? NSAttributedString(string: "", attributes: bodyTextAttributes())
            : NSAttributedString(string: inputText, attributes: bodyTextAttributes())
        let text = NSMutableAttributedString()
        if let prefix { text.append(prefix) }
        text.append(body)

        isApplyingTextStorage = true
        textView.attributedText = text
        textView.typingAttributes = bodyTextAttributes()
        let prefixLength = prefix?.length ?? 0
        let clampedOffset = min(max(0, bodyOffset), (inputText as NSString).length)
        textView.selectedRange = NSRange(location: prefixLength + clampedOffset, length: 0)
        isApplyingTextStorage = false
        updatePlaceholder()
    }

    func syncTextFromTextViewIfNeeded() {
        guard !isApplyingTextStorage else { return }
        let prefixLength = currentPrefixLength()
        let display = (textView.text ?? "") as NSString
        let nextText: String
        if prefixLength > 0, display.length >= prefixLength {
            nextText = display.substring(from: prefixLength)
        } else {
            nextText = display as String
        }
        guard nextText != inputText else { updatePlaceholder(); return }
        inputText = nextText
        textView.typingAttributes = bodyTextAttributes()
        notifyPreferredHeightChanged()
        onTextChanged?(inputText)
    }

    fileprivate func rangeTouchesPrefix(_ range: NSRange) -> Bool {
        let prefixLength = currentPrefixLength()
        guard prefixLength > 0 else { return false }
        return range.location < prefixLength
    }

    func measuredInputTextHeight(width: CGFloat, font: UIFont) -> CGFloat {
        let measuringText = displayAttributedStringForMeasurement(font: font)
        let bounds = measuringText.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(bounds.height)
    }

    fileprivate func currentBodySelectionOffset() -> Int {
        max(0, textView.selectedRange.location - currentPrefixLength())
    }

    fileprivate func currentPrefixLength() -> Int {
        prefixAttributedString()?.length ?? 0
    }

    fileprivate func displayAttributedStringForMeasurement(font: UIFont) -> NSAttributedString {
        let text = NSMutableAttributedString()
        if let prefix = prefixAttributedString(font: font) {
            text.append(prefix)
        }
        let body = inputText.isEmpty && text.length == 0 ? " " : inputText
        text.append(NSAttributedString(string: body, attributes: bodyTextAttributes(font: font)))
        return text
    }

    fileprivate func prefixAttributedString(font: UIFont? = nil) -> NSAttributedString? {
        guard let inputPrefix else { return nil }
        let font = font ?? textView.font ?? .systemFont(ofSize: ElysBarMetrics.inputFontSize, weight: .medium)
        let text = NSMutableAttributedString()
        if let icon = assetLoader.imageAspectFit(
            named: inputPrefix.icon,
            maxSize: CGSize(width: 20, height: 20)
        ) {
            let attachment = NSTextAttachment()
            attachment.image = icon.withTintColor(
                prefixTextColor,
                renderingMode: .alwaysOriginal
            )
            attachment.bounds = CGRect(
                x: 0,
                y: (font.capHeight - 20) / 2,
                width: 20,
                height: 20
            )
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(
                string: nonBreakingSpace,
                attributes: prefixTextAttributes(font: font)
            ))
        }
        let prefixText = inputPrefix.text.replacingOccurrences(of: " ", with: nonBreakingSpace)
        text.append(NSAttributedString(
            string: "\(prefixText)\(nonBreakingSpace)\(nonBreakingSpace)",
            attributes: prefixTextAttributes(font: font)
        ))
        return text
    }

    fileprivate func bodyTextAttributes(font: UIFont? = nil) -> [NSAttributedString.Key: Any] {
        [
            .font: font ?? textView.font ?? .systemFont(ofSize: ElysBarMetrics.inputFontSize, weight: .medium),
            .foregroundColor: UIColor(
                red: 0x1F / 255.0,
                green: 0x1F / 255.0,
                blue: 0x25 / 255.0,
                alpha: 1.0
            )
        ]
    }

    fileprivate func prefixTextAttributes(font: UIFont) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: prefixTextColor
        ]
    }

    fileprivate func isSamePrefix(
        _ lhs: ElysInputPrefixConfig?,
        _ rhs: ElysInputPrefixConfig?
    ) -> Bool {
        lhs?.id == rhs?.id && lhs?.icon == rhs?.icon && lhs?.text == rhs?.text
    }

    private var nonBreakingSpace: String { "\u{00A0}" }

    private var prefixTextColor: UIColor {
        UIColor(
            red: 0x57 / 255.0,
            green: 0x6B / 255.0,
            blue: 0x92 / 255.0,
            alpha: 1.0
        )
    }
}

private extension NSRange {
    var upperBound: Int { location + length }
}
