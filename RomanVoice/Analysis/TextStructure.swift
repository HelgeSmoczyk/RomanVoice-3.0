import Foundation

enum TextStructure {

    static func assignExplicitSpeakers(_ book: inout Novel) {
        let pattern = #"^\s*[,–—-]?\s*(?:sagte|fragte|antwortete|erwiderte|rief|flüsterte|murmelte)\s+([A-ZÄÖÜ][a-zäöüß]+)\b"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return
        }

        let source = book.text as NSString

        for i in book.segments.indices
        where book.segments[i].dialogue && book.segments[i].speaker == nil {

            let end =
                book.segments[i].offset +
                (book.segments[i].text as NSString).length

            let safeEnd = min(end, source.length)
            let tailLength = min(
                160,
                max(0, source.length - safeEnd)
            )

            let tail = source.substring(
                with: NSRange(
                    location: safeEnd,
                    length: tailLength
                )
            )

            guard let match = regex.firstMatch(
                in: tail,
                range: NSRange(
                    location: 0,
                    length: (tail as NSString).length
                )
            ) else {
                continue
            }

            let name = (tail as NSString).substring(
                with: match.range(at: 1)
            )

            guard ![
                "Er", "Sie", "Ich", "Du",
                "Wir", "Ihr", "Der", "Die",
                "Das", "Ein", "Eine"
            ].contains(name) else {
                continue
            }

            book.segments[i].speaker = name

            let knownCharacter = book.characters.first {
                $0.name == name
            }

            book.segments[i].analyzed =
                knownCharacter?.gender != .unknown

            if knownCharacter == nil {
                book.characters.append(
                    CharacterRole(
                        name: name,
                        firstOffset: book.segments[i].offset
                    )
                )
            }
        }
    }

    static func chapters(_ text: String) -> [Chapter] {
        let pattern =
        #"(?m)^[\t ]*(?:Kapitel[\t ]+[^\n]+|Prolog[^\n]*|Epilog[^\n]*|[IVXLCDM]+\.?|\d+\.?)[\t ]*$"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let ns = text as NSString

        return regex.matches(
            in: text,
            range: NSRange(
                location: 0,
                length: ns.length
            )
        ).map {
            Chapter(
                title: ns.substring(with: $0.range)
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                offset: $0.range.location
            )
        }
    }

    static func segments(
        _ text: String,
        chapters: [Chapter]
    ) -> [TextSegment] {

        let ns = text as NSString

        let quotePattern =
        #"„[^“]*“|»[^«]*«|«[^»]*»|“[^”]*”|"[^"]*""#

        let quoteRegex = try? NSRegularExpression(
            pattern: quotePattern
        )

        let quoteRanges =
            quoteRegex?
                .matches(
                    in: text,
                    range: NSRange(
                        location: 0,
                        length: ns.length
                    )
                )
                .map(\.range)
            ?? []

        var output: [TextSegment] = []

        func chapterIndex(for offset: Int) -> Int {
            chapters.lastIndex {
                $0.offset <= offset
            } ?? 0
        }

        func add(
            _ range: NSRange,
            dialogue: Bool
        ) {
            guard range.length > 0 else {
                return
            }

            let value = ns.substring(with: range)

            guard !value
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty else {
                return
            }

            if dialogue {
                /*
                 Anführungszeichen sind ein starkes strukturelles
                 Signal für Dialog.

                 Sprecher und Geschlecht sind aber noch NICHT
                 abschließend analysiert.
                 */
                output.append(
                    TextSegment(
                        offset: range.location,
                        text: value,
                        chapter: chapterIndex(
                            for: range.location
                        ),
                        speaker: nil,
                        dialogue: true,
                        analyzed: false
                    )
                )

            } else {
                /*
                 WICHTIGE KORREKTUR:

                 Text außerhalb erkannter Anführungszeichen wird
                 weiterhin deterministisch in Sätze zerlegt.

                 Er wird aber NICHT mehr mit
                     analyzed = true
                 endgültig aus der KI-Analyse ausgeschlossen.

                 "Erzähler" ist hier lediglich die vorläufige,
                 sichere Standardzuordnung.

                 LocalEngine/Qwen darf diese Vorentscheidung
                 anschließend überprüfen.
                 */
                value.enumerateSubstrings(
                    in: value.startIndex..<value.endIndex,
                    options: [
                        .bySentences,
                        .substringNotRequired
                    ]
                ) { _, subrange, _, _ in

                    let localRange = NSRange(
                        subrange,
                        in: value
                    )

                    let absoluteOffset =
                        range.location +
                        localRange.location

                    let absoluteRange = NSRange(
                        location: absoluteOffset,
                        length: localRange.length
                    )

                    let sentence =
                        ns.substring(
                            with: absoluteRange
                        )

                    guard !sentence
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty else {
                        return
                    }

                    output.append(
                        TextSegment(
                            offset: absoluteOffset,
                            text: sentence,
                            chapter: chapterIndex(
                                for: absoluteOffset
                            ),
                            speaker: "Erzähler",
                            dialogue: false,
                            analyzed: false
                        )
                    )
                }
            }
        }

        var cursor = 0

        for range in quoteRanges {
            if range.location > cursor {
                add(
                    NSRange(
                        location: cursor,
                        length: range.location - cursor
                    ),
                    dialogue: false
                )
            }

            add(
                range,
                dialogue: true
            )

            cursor = NSMaxRange(range)
        }

        if cursor < ns.length {
            add(
                NSRange(
                    location: cursor,
                    length: ns.length - cursor
                ),
                dialogue: false
            )
        }

        return output.sorted {
            $0.offset < $1.offset
        }
    }

    static func sentenceStart(
        _ offset: Int,
        text: String
    ) -> Int {

        var found = 0

        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [
                .bySentences,
                .substringNotRequired
            ]
        ) { _, range, _, stop in

            let nsRange = NSRange(
                range,
                in: text
            )

            if nsRange.location > offset {
                stop = true
            } else {
                found = nsRange.location
            }
        }

        return found
    }

    static func audioSegments(
        _ segments: [TextSegment]
    ) -> [TextSegment] {

        segments.flatMap {
            segment -> [TextSegment] in

            if segment.audioFile != nil {
                return [segment]
            }

            var parts: [TextSegment] = []

            segment.text.enumerateSubstrings(
                in:
                    segment.text.startIndex
                    ..<
                    segment.text.endIndex,
                options: [
                    .bySentences,
                    .substringNotRequired
                ]
            ) { _, range, _, _ in

                let localRange = NSRange(
                    range,
                    in: segment.text
                )

                var part = TextSegment(
                    passageID:
                        segment.passageID
                        ?? segment.id,
                    offset:
                        segment.offset
                        + localRange.location,
                    text:
                        String(
                            segment.text[range]
                        ),
                    chapter:
                        segment.chapter,
                    speaker:
                        segment.speaker,
                    dialogue:
                        segment.dialogue,
                    analyzed:
                        segment.analyzed
                )

                part.error = segment.error

                parts.append(part)
            }

            return parts.isEmpty
                ? [segment]
                : parts
        }
    }

    static func batches(
        _ segments: [TextSegment],
        target: Int = 3500
    ) -> [[Int]] {

        var batches: [[Int]] = []
        var group: [Int] = []
        var count = 0

        for i in segments.indices {
            group.append(i)
            count += segments[i].text.count

            if count >= target {
                batches.append(group)
                group = []
                count = 0
            }
        }

        if !group.isEmpty {
            batches.append(group)
        }

        return batches
    }
}
