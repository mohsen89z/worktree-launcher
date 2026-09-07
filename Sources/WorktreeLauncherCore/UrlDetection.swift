import Foundation

public enum UrlDetection {
    private static let pattern = #"https?://(?:localhost|127\.0\.0\.1|0\.0\.0\.0):\d{2,5}/?"#

    public static func detectURLs(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var seen = Set<String>()
        return regex.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            let url = String(text[swiftRange])
            return seen.insert(url).inserted ? url : nil
        }
    }
}
