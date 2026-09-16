import SwiftUI

struct BookDetailView: View {
    let id: UUID
    @EnvironmentObject var library: Library
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var player: AudioPlayer
    @EnvironmentObject var work: WorkCoordinator
    @State private var sheet: String?
    @State private var word = ""
    @State private var replacement = ""
    @State private var deleteKind: String?
    var body: some View {
        if let book = library.book(id) {
            VStack {
                PageHeader(title: book.title, subtitle: book.author) { navigation.go(.library(.library), room: .library) }
                Spacer(minLength: 40)
                ScrollView {
                    RomanPanel {
                        VStack {
                            MenuRow(title: "Lesen · \(book.percent(book.reading)) %", subtitle: "Eigene Leseposition", icon: "book") { navigation.go(.reader(id, nil, false), room: .reading) }
                            MenuRow(title: "Hören · \(book.percent(book.listening)) %", subtitle: book.hasAudio ? "Eigene Hörposition" : "Noch kein Audio erstellt", icon: "headphones") { player.open(id); navigation.go(.player(id), room: .audio) }
                            Divider()
                            MenuRow(title: "Kapitel", subtitle: "Originale Kapitelstruktur", icon: "list.bullet") { sheet = "Kapitel" }
                            MenuRow(title: "Buchinformationen", subtitle: book.sourceName, icon: "info.circle") { sheet = "Informationen" }
                            MenuRow(title: "Erstellungsstatus", subtitle: "Analyse \(Int(book.analysisProgress * 100)) % · Audio \(Int(book.audioProgress * 100)) %", icon: "waveform") { navigation.go(.analyze(id), room: .desk) }
                            MenuRow(title: "Aussprache", subtitle: "Wörterbuch dieses Romans", icon: "text.bubble") { sheet = "Aussprache" }
                            MenuRow(title: "Speicher verwalten", subtitle: ByteCountFormatter.string(fromByteCount: (try? AppFiles.size(AppFiles.book(id))) ?? 0, countStyle: .file), icon: "internaldrive") { sheet = "Speicher" }
                        }
                    }.padding(18)
                }
            }
            .sheet(isPresented: Binding(get: { sheet != nil }, set: { if !$0 { sheet = nil } })) {
                NavigationStack {
                    Form {
                        switch sheet {
                        case "Kapitel":
                            if book.chapters.isEmpty { Text("Dieses Werk hat keine erkannten Kapitelüberschriften.") }
                            ForEach(book.chapters) { chapter in Button(chapter.title) { sheet = nil; navigation.go(.reader(id, chapter.offset, false), room: .reading) } }
                        case "Informationen":
                            TextField("Titel", text: Binding(get: { library.book(id)?.title ?? "" }, set: { value in library.update(id) { $0.title = value } }))
                            TextField("Autor", text: Binding(get: { library.book(id)?.author ?? "" }, set: { value in library.update(id) { $0.author = value } }))
                            LabeledContent("Quelldatei", value: book.sourceName)
                            LabeledContent("Netzwerk", value: book.network.rawValue)
                            Toggle("Lesen beendet", isOn: Binding(get: { book.reading.completed }, set: { value in library.update(id) { $0.reading.completed = value } }))
                            Text("Der Originaltext bleibt durch die Analyse unverändert.")
                        case "Aussprache":
                            ForEach(book.pronunciation) { Text("\($0.word) → \($0.replacement)") }
                            TextField("Wort oder Name", text: $word)
                            TextField("So aussprechen (Lautschrift in Buchstaben)", text: $replacement)
                            Button("Nur zukünftige Stellen") { correct(regenerate: false) }.disabled(word.isEmpty || replacement.isEmpty)
                            Button("Betroffene Stellen neu erzeugen") { player.pause(); correct(regenerate: true) }.disabled(word.isEmpty || replacement.isEmpty || !book.voicesConfirmed)
                        case "Speicher":
                            Text("Original, Analysedaten und Audio werden getrennt verwaltet. Der aufbereitete Lesetext bleibt beim Entfernen der Originaldatei erhalten.")
                            Button("Originaldatei entfernen", role: .destructive) { deleteKind = "Original" }.disabled(book.sourceFile == nil || work.activeID == id || book.analysisProgress < 1)
                            Button("Audio entfernen, Roman behalten", role: .destructive) { deleteKind = "Audio" }.disabled(work.activeID == id)
                            Button("Roman vollständig löschen", role: .destructive) { deleteKind = "Alles" }.disabled(work.activeID == id)
                        default: EmptyView()
                        }
                    }.navigationTitle(sheet ?? "").toolbar { Button("Fertig") { sheet = nil } }
                    .confirmationDialog("\(deleteKind ?? "") wirklich entfernen?", isPresented: Binding(get: { deleteKind != nil }, set: { if !$0 { deleteKind = nil } })) {
                        Button("Entfernen", role: .destructive) { remove() }
                    }
                }
            }
        }
    }
    private func correct(regenerate: Bool) { work.pronunciation(id, rule: Pronunciation(word: word, replacement: replacement), regenerate: regenerate); word = ""; replacement = "" }
    private func remove() {
        do {
            if player.bookID == id { player.pause() }
            switch deleteKind { case "Original": try library.removeOriginal(id); case "Audio": try library.removeAudio(id); case "Alles": try library.delete(id); sheet = nil; navigation.go(.library(.library), room: .library); default: break }
        } catch { library.error = error.localizedDescription }
        deleteKind = nil
    }
}
