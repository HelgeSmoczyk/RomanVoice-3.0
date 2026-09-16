import XCTest
import CryptoKit
@testable import RomanVoice

final class RomanVoiceTests: XCTestCase {
    func testPronunciationDoesNotRewriteOtherNames() {
        let result = PronunciationEngine.apply("Anna und Hanna treffen Anna.", rules: [Pronunciation(word: "Anna", replacement: "Ahna")])
        XCTAssertEqual(result, "Ahna und Hanna treffen Ahna.")
    }
    func testAudioSentenceSplitKeepsSpeechPassageIdentity() {
        let segment = TextSegment(offset: 40, text: "Erster Satz. Zweiter Satz. Dritter Satz. Vierter Satz.", chapter: 0, speaker: "Anna", dialogue: true, analyzed: true)
        let result = TextStructure.audioSegments([segment])
        XCTAssertGreaterThan(result.count, 1)
        XCTAssertEqual(Set(result.compactMap(\.passageID)).count, 1)
        XCTAssertEqual(result[0].offset, 40)
    }
    func testUnicodeTextAnchorsAndDialoguesAreNotSplit() {
        let quote = "„Änne, grüß den zwölfjährigen Jungen! " + String(repeating: "Ein langer Satz. ", count: 500) + "Jetzt fertig.“"
        let text = "Kapitel 1\nEin Anfang.\n" + quote + " sagte Alexandra.\nKapitel 2\nEin Ende."
        let chapters = TextStructure.chapters(text)
        let segments = TextStructure.segments(text, chapters: chapters)
        let dialogues = segments.filter(\.dialogue)
        XCTAssertEqual(dialogues.count, 1)
        XCTAssertEqual(dialogues.first?.text, quote)
        let ns = text as NSString
        for segment in segments {
            XCTAssertEqual(ns.substring(with: NSRange(location: segment.offset, length: (segment.text as NSString).length)), segment.text)
        }
        XCTAssertEqual(TextStructure.batches(segments).flatMap { $0 }, Array(segments.indices))
        XCTAssertEqual(chapters.map(\.title), ["Kapitel 1", "Kapitel 2"])
    }
    func testExplicitSpeakerAndMinorRoleBoundary() {
        let text = "„Hallo.“ sagte Anna. „Wieder.“ sagte Anna. „Drei.“ sagte Anna. „Vier.“ sagte Anna."
        var book = Novel(title: "Test", sourceName: "test.txt", text: text)
        book.segments = TextStructure.segments(text, chapters: [])
        TextStructure.assignExplicitSpeakers(&book)
        XCTAssertEqual(book.segments.filter { $0.speaker == "Anna" }.count, 4)
        var role = CharacterRole(name: "Anna", appearances: 3)
        XCTAssertTrue(role.isMinor)
        role.appearances = 4
        XCTAssertFalse(role.isMinor)
    }
    func testReadAndListenPositionsRemainIndependentThroughSerialization() throws {
        var book = Novel(title: "Positionen", sourceName: "test.txt", text: "Ein Buch.")
        book.reading = Position(offset: 17)
        book.listening = Position(offset: 983, seconds: 4.5)
        book.reading.offset = 41
        let restored = try JSONDecoder().decode(Novel.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(restored.listening.offset, 983)
        XCTAssertEqual(restored.listening.seconds, 4.5)
        XCTAssertEqual(restored.reading.offset, 41)
    }
    func testCheckpointsPreserveExplicitCancellation() throws {
        var book = Novel(title: "Abbruch", sourceName: "test.txt", text: "Ein Satz.")
        book.phase = .cancelled; book.interruptedPhase = .analyzing; book.explicitStop = true
        book.segments = [TextSegment(offset: 0, text: "Ein Satz.", chapter: 0, speaker: "Erzähler", dialogue: false, analyzed: true, audioFile: "segment.rvaudio", duration: 2.5)]
        let restored = try JSONDecoder().decode(Novel.self, from: JSONEncoder().encode(book))
        XCTAssertTrue(restored.explicitStop)
        XCTAssertEqual(restored.segments[0].audioFile, "segment.rvaudio")
        XCTAssertEqual(restored.analysisProgress, 1)
    }
    @MainActor func testOriginalRemovalDoesNotRemoveAudio() throws {
        let library = Library()
        var book = Novel(title: "Speichertest", sourceName: "input.txt", sourceFile: "original.txt", text: "Behalten.")
        let dir = try AppFiles.book(book.id)
        defer { try? library.delete(book.id) }
        try AppFiles.write(Data("Original".utf8), to: dir.appendingPathComponent("original.txt"))
        try AppFiles.write(Data("Audio".utf8), to: dir.appendingPathComponent("audio.rvaudio"))
        book.segments = [TextSegment(offset: 0, text: book.text, chapter: 0, speaker: "Erzähler", dialogue: false, audioFile: "audio.rvaudio")]
        try library.save(book)
        try library.removeOriginal(book.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("audio.rvaudio").path))
        XCTAssertEqual(library.book(book.id)?.text, "Behalten.")
        XCTAssertNil(library.book(book.id)?.sourceFile)
    }
    @MainActor func testPaginationHasAtMost34LinesAndChaptersStartNewPage() {
        let text = "Kapitel 1\n" + String(repeating: "Eine lange Geschichte geht weiter. ", count: 200) + "\nKapitel 2\nEin neuer Anfang."
        var book = Novel(title: "Satz", sourceName: "test.txt", text: text)
        book.chapters = TextStructure.chapters(text)
        let layout = BookLayout(book: book)
        XCTAssertTrue(layout.pages.allSatisfy { $0.lines.count <= 34 })
        let chapter = book.chapters[1]
        XCTAssertEqual(layout.pages[layout.page(at: chapter.offset)].offset, chapter.offset)
    }
    func testAudioEncryptionRejectsTampering() throws {
        let folder = try AppFiles.directory("Tests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("test.rvaudio")
        let data = Data("Private Audio".utf8)
        try AudioVault.store(data, at: url)
        XCTAssertEqual(try AudioVault.read(url), data)
        var encrypted = try Data(contentsOf: url)
        encrypted[encrypted.count / 2] ^= 1
        try encrypted.write(to: url)
        XCTAssertThrowsError(try AudioVault.read(url))
    }
}
