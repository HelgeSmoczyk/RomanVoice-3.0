import Foundation
import Combine
import UserNotifications

@MainActor final class WorkCoordinator: ObservableObject {
    @Published var activeID: UUID?
    @Published var activity = ""
    @Published var progress: Double = 0
    private var task: Task<Void, Never>?
    private var foreground = true
    private var resumeWhenIdle = false
    private let library: Library
    private let model: ModelManager
    private let engine = LocalEngine()
    private let renderer = SpeechRenderer()
    var audioChanged: (() -> Void)?
    init(library: Library, model: ModelManager) { self.library = library; self.model = model }
    func analyze(_ id: UUID) {
        guard activeID == nil else { return }
        guard model.ready else { library.error = "Bitte zuerst die kostenlose KI unter Einstellungen herunterladen."; return }
        library.update(id) { book in
            if book.segments.isEmpty { book.chapters = TextStructure.chapters(book.text); book.segments = TextStructure.segments(book.text, chapters: book.chapters) }
            book.phase = .analyzing; book.explicitStop = false; book.error = nil
            TextStructure.assignExplicitSpeakers(&book)
        }
        activeID = id; activity = "Textstruktur wird geprüft …"
        task = Task {
            defer { self.finishedTask(); self.engine.release() }
            do {
                guard let initial = library.book(id) else { return }
                let groups = TextStructure.batches(initial.segments)
                for group in groups {
                    try Task.checkCancellation()
                    guard var book = library.book(id) else { return }
                    for index in group {
                        if let name = book.segments[index].speaker, let role = book.characters.first(where: { $0.name == name }), role.gender != .unknown { book.segments[index].analyzed = true }
                    }
                    let pending = group.filter { !book.segments[$0].analyzed }
                    guard !pending.isEmpty else { try library.save(book); continue }
                    activity = "Sprecher prüfen · Abschnitt \((group.first ?? 0) + 1) von \(book.segments.count)"
                    do {
                        let response = try await engine.generate(LocalEngine.prompt(book: book, indices: group), modelURL: model.url)
                        try Task.checkCancellation()
                        book = library.book(id) ?? book
                        let answer = try LocalEngine.decode(response)
                        for assignment in answer.assignments where pending.contains(assignment.index) {
                            let name = assignment.speaker?.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard assignment.confidence >= 0.8, let name, !name.isEmpty, name != "UNGEKLÄRT", name != "Erzähler" else { continue }
                            guard book.text.localizedCaseInsensitiveContains(name) || book.characters.contains(where: { $0.name == name }) else { continue }
                            if let explicit = book.segments[assignment.index].speaker, explicit != name { continue }
                            book.segments[assignment.index].speaker = name
                            let gender: Gender = assignment.gender == "male" ? .male : assignment.gender == "female" ? .female : .unknown
                            if !book.characters.contains(where: { $0.name == name }) {
                                book.characters.append(CharacterRole(name: name, gender: gender, firstOffset: book.segments[assignment.index].offset))
                            } else if let role = book.characters.firstIndex(where: { $0.name == name }), book.characters[role].gender == .unknown {
                                book.characters[role].gender = gender
                            }
                        }
                    } catch {
                        try Task.checkCancellation()
                        for index in pending { book.segments[index].error = error.localizedDescription }
                    }
                    for index in pending { book.segments[index].analyzed = true }
                    countRoles(&book); try library.save(book); progress = book.analysisProgress
                }
                guard var finished = library.book(id) else { return }
                countRoles(&finished); VoiceCatalog.suggest(&finished)
                finished.phase = .review; finished.interruptedPhase = nil
                try library.save(finished); progress = 1; activity = "Analyse abgeschlossen · Stimmen prüfen"
                notify(id: id.uuidString + "review", title: "Analyse abgeschlossen", body: "Bitte Stimmen und offene Zuordnungen prüfen.")
            } catch is CancellationError { }
            catch { fail(id, phase: .analyzing, error: error) }
        }
    }
    func countRoles(_ book: inout Novel) {
        for index in book.characters.indices {
            let name = book.characters[index].name
            book.characters[index].appearances = Set(book.segments.filter { $0.dialogue && $0.speaker == name }.map { $0.passageID ?? $0.id }).count
        }
        book.characters.removeAll { !$0.isNarrator && $0.appearances == 0 }
    }
    func render(_ id: UUID) {
        guard activeID == nil, var book = library.book(id) else { return }
        guard book.characters.allSatisfy({ $0.voice != nil }) else { library.error = "Bitte allen Figuren und dem Erzähler eine Stimme zuweisen."; return }
        guard book.voicesConfirmed else { library.error = "Bitte die Stimmenauswahl bestätigen."; return }
        if !book.hasAudio { book.segments = TextStructure.audioSegments(book.segments) }
        book.phase = .rendering; book.explicitStop = false; book.error = nil
        do { try library.save(book) } catch { library.error = error.localizedDescription; return }
        activeID = id
        task = Task {
            defer { self.finishedTask() }
            do {
                for index in book.segments.indices {
                    try Task.checkCancellation()
                    guard var current = library.book(id) else { return }
                    let item = current.segments[index]
                    if item.audioFile != nil { continue }
                    guard let speaker = item.speaker, let voice = current.characters.first(where: { $0.name == speaker })?.voice else {
                        current.phase = .review; current.interruptedPhase = .rendering
                        try library.save(current); activity = "Sprecherentscheidung erforderlich"
                        notify(id: id.uuidString + "decision", title: "Entscheidung erforderlich", body: "Eine Sprecherstelle wartet auf deine Zuordnung.")
                        return
                    }
                    activity = "Hörbuch erstellen · Abschnitt \(index + 1) von \(current.segments.count)"
                    let text = PronunciationEngine.apply(item.text, rules: current.pronunciation)
                    let (data, duration) = try await renderer.render(text, choice: voice)
                    try Task.checkCancellation()
                    current = library.book(id) ?? current
                    let filename = item.id.uuidString + ".rvaudio"
                    try AudioVault.store(data, at: AppFiles.book(id).appendingPathComponent(filename))
                    current.segments[index].audioFile = filename; current.segments[index].duration = duration
                    let previousDuration = current.segments.prefix(index).reduce(0) { $0 + $1.duration }
                    try library.save(current); progress = current.audioProgress; audioChanged?()
                    if previousDuration < 600 && previousDuration + duration >= 600 {
                        notify(id: id.uuidString + "start", title: "Bereit zum Hören", body: "Die ersten zehn Minuten sind fertig. Die Erstellung läuft weiter.")
                    }
                }
                library.update(id) { $0.phase = .ready; $0.interruptedPhase = nil }
                activity = "Hörbuch vollständig erstellt"; progress = 1
                notify(id: id.uuidString + "complete", title: "Hörbuch fertig", body: "Dein Hörbuch ist vollständig offline verfügbar.")
            } catch is CancellationError { }
            catch { fail(id, phase: .rendering, error: error) }
        }
    }
    func stop(explicit: Bool) {
        guard let id = activeID else { return }
        library.update(id) { book in book.interruptedPhase = book.phase; book.explicitStop = explicit; book.phase = explicit ? .cancelled : .paused }
        task?.cancel(); engine.cancel(); renderer.cancel()
        activity = explicit ? "Abgebrochen · gespeicherte Schritte bleiben erhalten" : "Pausiert · Checkpoint gesichert"
    }
    func resume(_ id: UUID) {
        guard activeID == nil, let book = library.book(id) else { return }
        if book.interruptedPhase == .rendering || book.phase == .rendering { render(id) } else { analyze(id) }
    }
    func resumeAutomatic() {
        guard foreground else { return }
        guard activeID == nil else { resumeWhenIdle = true; return }
        if let book = library.books.first(where: { !$0.explicitStop && [.analyzing, .rendering, .paused, .failed].contains($0.phase) }) { resume(book.id) }
    }
    func setForeground(_ value: Bool) {
        foreground = value
        if value { resumeAutomatic() } else { stop(explicit: false) }
    }
    private func finishedTask() {
        activeID = nil; task = nil
        if resumeWhenIdle && foreground {
            resumeWhenIdle = false
            Task { await Task.yield(); resumeAutomatic() }
        }
    }
    func pronunciation(_ id: UUID, rule: Pronunciation, regenerate: Bool) {
        guard activeID == nil, var book = library.book(id) else { library.error = "Bitte die laufende Verarbeitung zuerst pausieren."; return }
        book.pronunciation.removeAll { $0.word == rule.word }; book.pronunciation.append(rule)
        if regenerate {
            for i in book.segments.indices where book.segments[i].text.contains(rule.word) {
                if let filename = book.segments[i].audioFile { try? FileManager.default.removeItem(at: AppFiles.book(id).appendingPathComponent(filename)) }
                book.segments[i].audioFile = nil; book.segments[i].duration = 0
            }
            book.phase = .review; book.interruptedPhase = .rendering
        }
        do { try library.save(book) } catch { library.error = error.localizedDescription }
        if regenerate { render(id) }
    }
    private func fail(_ id: UUID, phase: WorkPhase, error: Error) {
        library.update(id) { $0.phase = .failed; $0.interruptedPhase = phase; $0.error = error.localizedDescription }
        activity = error.localizedDescription
    }
    private func notify(id: String, title: String, body: String) {
        guard library.preferences.notifications else { return }
        let content = UNMutableNotificationContent(); content.title = title; content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
