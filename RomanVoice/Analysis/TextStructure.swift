import Foundation

enum TextStructure {
    static func assignExplicitSpeakers(_ book: inout Novel) {
        let pattern = #"^\s*[,–—-]?\s*(?:sagte|fragte|antwortete|erwiderte|rief|flüsterte|murmelte)\s+([A-ZÄÖÜ][a-zäöüß]+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let source = book.text as NSString
        for i in book.segments.indices where book.segments[i].dialogue && book.segments[i].speaker == nil {
            let end = book.segments[i].offset + (book.segments[i].text as NSString).length
            let tail = source.substring(with: NSRange(location: min(end, source.length), length: min(160, max(0, source.length - end))))
            guard let match = regex.firstMatch(in: tail, range: NSRange(location: 0, length: (tail as NSString).length)) else { continue }
            let name = (tail as NSString).substring(with: match.range(at: 1))
            guard !["Er", "Sie", "Ich", "Du", "Wir", "Ihr", "Der", "Die", "Das", "Ein", "Eine"].contains(name) else { continue }
            book.segments[i].speaker = name
            book.segments[i].analyzed = book.characters.first(where: { $0.name == name })?.gender != .unknown && book.characters.contains(where: { $0.name == name })
            if !book.characters.contains(where: { $0.name == name }) { book.characters.append(CharacterRole(name: name, firstOffset: book.segments[i].offset)) }
        }
    }
    static func chapters(_ text: String) -> [Chapter] {
        let pattern = #"(?m)^[\t ]*(?:Kapitel[\t ]+[^\n]+|Prolog[^\n]*|Epilog[^\n]*|[IVXLCDM]+\.?|\d+\.?)[\t ]*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map {
            Chapter(title: (text as NSString).substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines), offset: $0.range.location)
        }
    }
    static func segments(_ text: String, chapters: [Chapter]) -> [TextSegment] {
        let ns = text as NSString
        let quotePattern = #"„[^“]*“|»[^«]*«|«[^»]*»|“[^”]*”|\"[^\"]*\""#
        let quote = try? NSRegularExpression(pattern: quotePattern)
        let ranges = quote?.matches(in: text, range: NSRange(location: 0, length: ns.length)).map(\.range) ?? []
        var output: [TextSegment] = []
        func add(_ range: NSRange, dialogue: Bool) {
            guard range.length > 0 else { return }
            let value = ns.substring(with: range)
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            if dialogue {
                output.append(TextSegment(offset: range.location, text: value, chapter: chapters.lastIndex(where: { $0.offset <= range.location }) ?? 0, speaker: nil, dialogue: true))
            } else {
                value.enumerateSubstrings(in: value.startIndex..<value.endIndex, options: [.bySentences, .substringNotRequired]) { _, subrange, _, _ in
                    let r = NSRange(subrange, in: value)
                    let offset = range.location + r.location
                    output.append(TextSegment(offset: offset, text: ns.substring(with: NSRange(location: offset, length: r.length)), chapter: chapters.lastIndex(where: { $0.offset <= offset }) ?? 0, speaker: "Erzähler", dialogue: false, analyzed: true))
                }
            }
        }
        var cursor = 0
        for range in ranges { add(NSRange(location: cursor, length: range.location - cursor), dialogue: false); add(range, dialogue: true); cursor = NSMaxRange(range) }
        add(NSRange(location: cursor, length: ns.length - cursor), dialogue: false)
        return output.sorted { $0.offset < $1.offset }
    }
    static func sentenceStart(_ offset: Int, text: String) -> Int {
        var found = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.bySentences, .substringNotRequired]) { _, range, _, stop in
            let r = NSRange(range, in: text)
            if r.location > offset { stop = true } else { found = r.location }
        }
        return found
    }
    static func audioSegments(_ segments: [TextSegment]) -> [TextSegment] {
        segments.flatMap { segment -> [TextSegment] in
            if segment.audioFile != nil { return [segment] }
            var parts: [TextSegment] = []
            segment.text.enumerateSubstrings(in: segment.text.startIndex..<segment.text.endIndex, options: [.bySentences, .substringNotRequired]) { _, range, _, _ in
                let local = NSRange(range, in: segment.text)
                var part = TextSegment(passageID: segment.passageID ?? segment.id, offset: segment.offset + local.location, text: String(segment.text[range]), chapter: segment.chapter, speaker: segment.speaker, dialogue: segment.dialogue, analyzed: segment.analyzed)
                part.error = segment.error; parts.append(part)
            }
            return parts.isEmpty ? [segment] : parts
        }
    }
    static func batches(_ segments: [TextSegment], target: Int = 3500) -> [[Int]] {
        var batches: [[Int]] = [], group: [Int] = [], count = 0
        for i in segments.indices {
            group.append(i); count += segments[i].text.count
            if count >= target { batches.append(group); group = []; count = 0 }
        }
        if !group.isEmpty { batches.append(group) }
        return batches
    }
}
