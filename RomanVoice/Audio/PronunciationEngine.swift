import Foundation

enum PronunciationEngine {
    static func apply(_ text: String, rules: [Pronunciation]) -> String {
        var output = text
        for rule in rules where !rule.word.isEmpty {
            let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: rule.word) + "(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let mutable = NSMutableString(string: output)
            for match in regex.matches(in: output, range: NSRange(location: 0, length: mutable.length)).reversed() { mutable.replaceCharacters(in: match.range, with: rule.replacement) }
            output = mutable as String
        }
        return output
    }
}
