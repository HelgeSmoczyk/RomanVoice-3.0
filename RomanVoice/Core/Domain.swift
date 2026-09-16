import Foundation

enum Gender: String, Codable, CaseIterable { case unknown = "Bitte auswählen", male = "Männlich", female = "Weiblich" }
enum NetworkPolicy: String, Codable, CaseIterable { case wifi = "Nur WLAN", cellular = "WLAN und mobile Daten" }
enum SpoilerPolicy: String, Codable, CaseIterable { case strict = "Streng", normal = "Normal", off = "Aus" }
enum WorkPhase: String, Codable { case imported, analyzing, review, rendering, ready, paused, cancelled, failed }
enum ReadingMode: String, Codable, CaseIterable { case horizontal = "Links / rechts", vertical = "Hoch / runter", buttons = "Schaltflächen" }
enum Intent: String { case library, read, listen, analyze }

struct VoiceChoice: Codable, Hashable {
    var identifier: String
    var pitch: Float = 1
    var tempo: Float = 1
}
struct CharacterRole: Identifiable, Codable {
    var id = UUID()
    var name: String
    var gender: Gender = .unknown
    var appearances = 0
    var firstOffset = 0
    var voice: VoiceChoice?
    var isNarrator = false
    var isMinor: Bool { !isNarrator && appearances <= 3 }
}
struct Chapter: Identifiable, Codable {
    var id = UUID()
    var title: String
    var offset: Int
}
struct TextSegment: Identifiable, Codable {
    var id = UUID()
    var passageID: UUID?
    var offset: Int
    var text: String
    var chapter: Int
    var speaker: String?
    var dialogue: Bool
    var analyzed = false
    var audioFile: String?
    var duration: Double = 0
    var error: String?
}
struct Position: Codable, Equatable {
    var offset = 0
    var seconds: Double = 0
    var completed = false
    var started = false
}
struct Pronunciation: Identifiable, Codable {
    var id = UUID()
    var word: String
    var replacement: String
}
struct Novel: Identifiable, Codable {
    var id = UUID()
    var title: String
    var author = ""
    var sourceName: String
    var sourceFile: String?
    var coverFile: String?
    var text: String
    var chapters: [Chapter] = []
    var segments: [TextSegment] = []
    var characters: [CharacterRole] = [CharacterRole(name: "Erzähler", isNarrator: true)]
    var pronunciation: [Pronunciation] = []
    var phase: WorkPhase = .imported
    var interruptedPhase: WorkPhase?
    var explicitStop = false
    var voicesConfirmed = false
    var network: NetworkPolicy = .wifi
    var spoilers: SpoilerPolicy = .normal
    var reading = Position()
    var listening = Position()
    var playbackRate: Float = 1
    var zoom: Double = 1
    var favorite = false
    var playlist = ""
    var modified = Date()
    var error: String?
    var analysisProgress: Double { Double(segments.filter(\.analyzed).count) / Double(max(1, segments.count)) }
    var audioProgress: Double { Double(segments.filter { $0.audioFile != nil }.count) / Double(max(1, segments.count)) }
    var hasAudio: Bool { segments.contains { $0.audioFile != nil } }
    var status: String {
        if reading.completed || listening.completed { return "Beendet" }
        return reading.started || listening.started || reading.offset > 0 || listening.offset > 0 ? "Angefangen" : "Noch nicht angefangen"
    }
    func segmentIndex(at offset: Int) -> Int {
        segments.lastIndex(where: { $0.offset <= offset }) ?? 0
    }
    func percent(_ position: Position) -> Int { position.completed ? 100 : min(99, Int(Double(position.offset) / Double(max(1, (text as NSString).length)) * 100)) }
}
struct AppPreferences: Codable {
    var readingMode: ReadingMode = .horizontal
    var spoilers: SpoilerPolicy = .normal
    var storageAccepted = false
    var notifications = false
    var profileName = ""
}
enum RomanError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
}
