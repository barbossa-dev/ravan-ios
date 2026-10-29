import Foundation

public extension String {
    /// "12" → "۱۲".
    var persianDigits: String {
        let digits: [Character] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
        return String(map { character in
            if let value = character.wholeNumberValue, character.isASCII { digits[value] } else { character }
        })
    }
}

public extension BinaryInteger {
    var persianDigits: String { String(self).persianDigits }
}

/// Normalises text so Arabic/Persian letter variants, ZWNJ, diacritics and case
/// never prevent a match ("ك" vs "ک", "مي‌شود" vs "میشود", "Water" vs "water").
/// Mirrors `SearchNormalizer` on Android.
public enum SearchNormalizer {
    public static func normalize(_ input: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().unicodeScalars {
            switch scalar {
            case "ي", "ى": result.append("ی")
            case "ك": result.append("ک")
            case "ة": result.append("ه")
            case "أ", "إ", "آ": result.append("ا")
            case "\u{200C}", "\u{200F}", "\u{200E}", "ـ": continue
            case "\u{064B}"..."\u{0652}": continue
            case "۰"..."۹":
                let offset = scalar.value - ("۰" as Unicode.Scalar).value
                result.append(Unicode.Scalar(UInt8(48 + offset)))
            default: result.append(scalar)
            }
        }
        return String(result)
    }
}
