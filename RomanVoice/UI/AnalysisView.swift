import SwiftUI
import AVFoundation

struct AnalysisView: View {
    let id: UUID
    @EnvironmentObject var library: Library
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var work: WorkCoordinator
    @EnvironmentObject var model: ModelManager
    @State private var voices = false
    @State private var reveal = false
    @State private var spoilerWarning = false
    @State private var selectedSegment: UUID?
    @State private var newName = ""
    @State private var chapterName = ""
    @State private var chapterOffset = "0"
    @State private var chapters = false
    var body: some View {
        if let book = library.book(id) {
            VStack(spacing: 12) {
                PageHeader(title: "Neuer Roman", subtitle: "Aus Texten werden Stimmen.") { navigation.go(.detail(id), room: .library) }
                WorkAnimation(active: work.activeID == id, rendering: book.phase == .rendering).frame(height: 180)
                ScrollView {
                    RomanPanel {
                        VStack(alignment: .leading, spacing: 15) {
                            Text(book.sourceName).font(.headline)
                            Text(work.activeID == id ? work.activity : status(book)).font(.subheadline)
                            ProgressView(value: book.phase == .rendering || book.phase == .ready ? book.audioProgress : book.analysisProgress)
                            Text("Analyse: \(Int(book.analysisProgress * 100)) % · Audio: \(Int(book.audioProgress * 100)) %").font(.caption)
                            if let error = book.error { Text(error).foregroundStyle(.orange) }
                            if work.activeID == id {
                                Button("Pausieren") { work.stop(explicit: false) }.buttonStyle(RomanButton())
                                Button(book.phase == .rendering ? "Erstellung abbrechen" : "Analyse abbrechen", role: .destructive) { work.stop(explicit: true) }.foregroundStyle(.red)
                            } else {
                                if !model.ready { Button("Kostenlose KI einrichten") { model.suggestedPolicy = book.network; navigation.go(.settings, room: .settings) }.buttonStyle(RomanButton(prominent: true)) }
                                if book.analysisProgress < 1 { Button("Analyse starten / fortsetzen") { work.analyze(id) }.buttonStyle(RomanButton(prominent: true)).disabled(!model.ready || work.activeID != nil) }
                                if book.phase == .cancelled || book.phase == .paused || book.phase == .failed { Button("Gespeicherten Auftrag fortsetzen") { work.resume(id) }.buttonStyle(RomanButton()) }
                                if book.analysisProgress == 1 && book.phase != .ready {
                                    Button("Figuren und Stimmen prüfen") { voices = true }.buttonStyle(RomanButton())
                                    Button("Hörbuch erstellen / fortsetzen") { work.render(id) }.buttonStyle(RomanButton(prominent: true)).disabled(!book.voicesConfirmed || work.activeID != nil)
                                }
                            }
                            Divider()
                            let unresolved = book.segments.filter { $0.dialogue && $0.speaker == nil }
                            Text("\(book.characters.count - 1) Figuren erkannt · \(unresolved.count) offene Sprecherstellen")
                            Picker("Spoilerschutz", selection: Binding(get: { book.spoilers }, set: { value in library.update(id) { $0.spoilers = value } })) { ForEach(SpoilerPolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                            ForEach(unresolved) { segment in
                                let visible = reveal || book.spoilers == .off || segment.offset <= max(book.reading.offset, book.listening.offset)
                                if visible {
                                    Button { selectedSegment = segment.id } label: { Text(segment.text).lineLimit(3).multilineTextAlignment(.leading) }
                                } else if book.spoilers == .normal {
                                    Text("Spätere Sprecherstelle · Kapitel \(segment.chapter + 1)").font(.caption)
                                }
                            }
                            if !unresolved.isEmpty && !reveal && book.spoilers != .off {
                                Button("Jetzt prüfen – kann Spoiler enthalten") { spoilerWarning = true }
                                Button("Später klären") { navigation.go(.detail(id), room: .library) }
                            }
                            Button("Kapitel prüfen / bearbeiten") { chapters = true }.disabled(book.hasAudio || work.activeID == id)
                        }
                    }.padding(.horizontal, 18).padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $voices) { VoiceReviewView(id: id) }
            .alert("Spätere Inhalte anzeigen?", isPresented: $spoilerWarning) { Button("Anzeigen") { reveal = true }; Button("Abbrechen", role: .cancel) {} } message: { Text("Diese Prüfung kann spätere Figuren und Handlung verraten.") }
            .sheet(isPresented: Binding(get: { selectedSegment != nil }, set: { if !$0 { selectedSegment = nil } })) {
                NavigationStack {
                    Form {
                        Text(book.segments.first(where: { $0.id == selectedSegment })?.text ?? "")
                        ForEach(book.characters) { character in Button(character.name) { assign(character.name) } }
                        TextField("Neue Figur", text: $newName)
                        Button("Figur anlegen und zuweisen") { assign(newName) }.disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }.navigationTitle("Wer spricht?").toolbar { Button("Später") { selectedSegment = nil } }
                }
            }
            .sheet(isPresented: $chapters) {
                NavigationStack {
                    Form {
                        ForEach(book.chapters) { chapter in
                            HStack { Text(chapter.title); Spacer(); Button("Entfernen", role: .destructive) { library.update(id) { $0.chapters.removeAll { $0.id == chapter.id } } } }
                        }
                        TextField("Originale Kapitelüberschrift", text: $chapterName)
                        Text("Die Überschrift wird im Originaltext gesucht. Es werden keine Titel erfunden.").font(.caption)
                        Button("Kapitelgrenze setzen") {
                            let range = (book.text as NSString).range(of: chapterName)
                            guard range.location != NSNotFound else { library.error = "Diese Überschrift steht nicht im Originaltext."; return }
                            library.update(id) { value in
                                value.chapters.append(Chapter(title: chapterName, offset: range.location)); value.chapters.sort { $0.offset < $1.offset }
                                for i in value.segments.indices { value.segments[i].chapter = value.chapters.lastIndex { $0.offset <= value.segments[i].offset } ?? 0 }
                            }
                            chapterName = ""
                        }.disabled(chapterName.isEmpty)
                    }.navigationTitle("Kapitel").toolbar { Button("Fertig") { chapters = false } }
                }
            }
        }
    }
    private func assign(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let segmentID = selectedSegment else { return }
        library.update(id) { book in
            guard let index = book.segments.firstIndex(where: { $0.id == segmentID }) else { return }
            if !book.characters.contains(where: { $0.name == name }) { book.characters.append(CharacterRole(name: name, firstOffset: book.segments[index].offset)) }
            book.segments[index].speaker = name; book.segments[index].error = nil; book.segments[index].analyzed = true
            work.countRoles(&book); VoiceCatalog.suggest(&book); book.voicesConfirmed = false
        }
        newName = ""; selectedSegment = nil
    }
    private func status(_ book: Novel) -> String {
        switch book.phase { case .imported: return "Bereit zur Analyse"; case .analyzing: return "Analyse wird fortgesetzt"; case .review: return "Analyse prüfen und Stimmen bestätigen"; case .rendering: return "Hörbuch wird erstellt"; case .ready: return "Vollständig offline verfügbar"; case .paused: return "Pausiert"; case .cancelled: return "Bewusst abgebrochen"; case .failed: return "Unterbrochen – Checkpoint vorhanden" }
    }
}

struct VoiceReviewView: View {
    let id: UUID
    @EnvironmentObject var library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var showNames = false
    var body: some View {
        NavigationStack {
            if let book = library.book(id) {
                List {
                    Text("\(VoiceCatalog.available.count) tatsächlich installierte deutsche Grundstimmen. Tonhöhe und Tempo erzeugen zusätzliche Varianten.").font(.caption)
                    if book.spoilers != .off && !showNames {
                        Text("Die vollständige Figurenliste kann spätere Figuren verraten.")
                        Button("Figurenliste bewusst öffnen") { showNames = true }
                    }
                    ForEach(book.characters.filter { $0.isNarrator || showNames || book.spoilers == .off || $0.firstOffset <= max(book.reading.offset, book.listening.offset) }) { character in
                        Section(character.isNarrator ? "Erzähler" : character.name + (character.isMinor ? " · Kleinstrolle" : "")) {
                            Picker("Geschlecht", selection: Binding(get: { character.gender }, set: { value in change(character.id) { $0.gender = value; $0.voice = nil } })) {
                                ForEach(Gender.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }
                            let voices = character.isNarrator || character.isMinor ? Array(VoiceCatalog.voices(character.gender).prefix(1)) : VoiceCatalog.voices(character.gender)
                            Picker("Grundstimme", selection: Binding(get: { character.voice?.identifier ?? "" }, set: { value in setVoice(character, identifier: value) })) {
                                Text("Bitte auswählen").tag("")
                                ForEach(voices, id: \.identifier) { Text($0.name).tag($0.identifier) }
                            }.disabled(character.gender == .unknown)
                            Picker("Tonhöhe", selection: Binding(get: { character.voice?.pitch ?? 1 }, set: { value in setVoice(character, pitch: value) })) {
                                Text("Tief").tag(Float(0.8)); Text("Normal").tag(Float(1)); Text("Hoch").tag(Float(1.2))
                            }
                            Picker("Tempo", selection: Binding(get: { character.voice?.tempo ?? 1 }, set: { value in setVoice(character, tempo: value) })) {
                                Text("Langsam").tag(Float(0.85)); Text("Normal").tag(Float(1)); Text("Schnell").tag(Float(1.15))
                            }
                            Button("Gewählte Variante probehören") {
                                guard let choice = character.voice else { return }
                                do { synthesizer.stopSpeaking(at: .immediate); synthesizer.speak(try VoiceCatalog.utterance("Eine neue Geschichte beginnt. Hörst du meine Stimme?", choice: choice)) }
                                catch { library.error = error.localizedDescription }
                            }.disabled(character.voice == nil)
                        }.disabled(book.voicesConfirmed || book.hasAudio)
                    }
                    if !book.voicesConfirmed && !book.hasAudio {
                        Button("Vollständige Stimmenauswahl bestätigen") { library.update(id) { $0.voicesConfirmed = true }; dismiss() }.disabled(book.characters.contains { $0.voice == nil || $0.gender == .unknown })
                    } else { Text("Stimmen sind für diese Erzeugung festgelegt.") }
                }.navigationTitle("Figuren & Stimmen").toolbar { Button("Fertig") { dismiss() } }
            }
        }.onDisappear { synthesizer.stopSpeaking(at: .immediate) }
    }
    private func change(_ roleID: UUID, mutation: (inout CharacterRole) -> Void) {
        library.update(id) { book in
            guard let index = book.characters.firstIndex(where: { $0.id == roleID }) else { return }
            mutation(&book.characters[index]); VoiceCatalog.suggest(&book)
        }
    }
    private func setVoice(_ role: CharacterRole, identifier: String? = nil, pitch: Float? = nil, tempo: Float? = nil) {
        guard let book = library.book(id) else { return }
        var choice = role.voice ?? VoiceChoice(identifier: VoiceCatalog.voices(role.gender).first?.identifier ?? "")
        if let identifier { choice.identifier = identifier }; if let pitch { choice.pitch = pitch }; if let tempo { choice.tempo = tempo }
        guard !choice.identifier.isEmpty, VoiceCatalog.allowed(choice, role: role, book: book) else { library.error = "Diese Variante ist bereits vergeben. Es gibt noch eine passende freie Variante."; return }
        change(role.id) { $0.voice = choice }
    }
}
