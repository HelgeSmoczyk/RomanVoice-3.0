import SwiftUI
import UniformTypeIdentifiers

enum Screen: Equatable { case home, library(Intent), detail(UUID), analyze(UUID), reader(UUID, Int?, Bool), player(UUID), settings }
@MainActor final class Navigation: ObservableObject {
    @Published var screen: Screen = .home
    @Published var room: Room = .salon
    func go(_ screen: Screen, room: Room) { withAnimation(.easeInOut(duration: 0.8)) { self.room = room; self.screen = screen } }
}
struct RootView: View {
    @EnvironmentObject var library: Library
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var model: ModelManager
    @EnvironmentObject var work: WorkCoordinator
    @EnvironmentObject var player: AudioPlayer
    @Environment(\.scenePhase) private var phase
    @State private var menu = false
    @State private var importing = false
    @State private var imported: ImportedDocument?
    @State private var network: NetworkPolicy = .wifi
    @State private var documentError: String?
    @State private var loading = false
    @State private var useCover = true
    var body: some View {
        ZStack {
            SceneBackdrop(room: navigation.room)
            Group {
                switch navigation.screen {
                case .home: salon
                case .library(let intent): LibraryView(intent: intent, importAction: { importing = true })
                case .detail(let id): BookDetailView(id: id)
                case .analyze(let id): AnalysisView(id: id)
                case .reader(let id, let offset, let preserve): ReaderView(id: id, initialOffset: offset, preservePosition: preserve).id("\(id)-\(offset ?? -1)-\(preserve)")
                case .player(let id): PlayerView(id: id)
                case .settings: SettingsView()
                }
            }.transition(.opacity)
            if loading { ProgressView("Datei wird gelesen …").padding(25).background(RomanStyle.green, in: RoundedRectangle(cornerRadius: 16)) }
        }
        .foregroundStyle(RomanStyle.cream).tint(RomanStyle.gold)
        .sheet(isPresented: $menu) { mainMenu.presentationDetents([.medium, .large]) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .plainText, UTType(filenameExtension: "docx") ?? .data]) { result in
            switch result { case .success(let url): importFile(url); case .failure(let error): documentError = error.localizedDescription }
        }
        .sheet(isPresented: Binding(get: { imported != nil }, set: { if !$0 { imported = nil } })) { importConfirmation }
        .alert("RomanVoice", isPresented: Binding(get: { documentError != nil || library.error != nil }, set: { if !$0 { documentError = nil; library.error = nil } })) {
            Button("OK") { documentError = nil; library.error = nil }
        } message: { Text(documentError ?? library.error ?? "") }
        .onOpenURL { importFile($0) }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in importFile(url) }
            }
            return true
        }
        .onChange(of: phase) { _, value in
            if value == .background { work.setForeground(false); player.persist() }
            if value == .active { work.setForeground(true) }
        }
        .onChange(of: model.ready) { _, ready in if ready { work.resumeAutomatic() } }
        .task { work.audioChanged = { player.availableAudioChanged() } }
    }
    private var salon: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    HStack {
                        Button { menu = true } label: { Image(systemName: "line.3.horizontal").frame(width: 44, height: 44) }.buttonStyle(RomanButton())
                        Spacer()
                        Button { navigation.go(.settings, room: .settings) } label: { Image(systemName: "gearshape").frame(width: 44, height: 44) }.buttonStyle(RomanButton())
                    }
                    Spacer()
                    HStack { Button("Impressum") { navigation.go(.settings, room: .settings) }; Text("·"); Button("Datenschutz") { navigation.go(.settings, room: .settings) }; Text("· 3.0") }.font(.caption2).shadow(radius: 5)
                }.padding(.horizontal, 15).padding(.bottom, 8)
                hotspot("Bibliothek", icon: "books.vertical", x: 0.22, y: 0.28, size: geometry.size) { navigation.go(.library(.library), room: .library) }
                hotspot("Lesen", icon: "book", x: 0.24, y: 0.55, size: geometry.size) { navigation.go(.library(.read), room: .reading) }
                hotspot("Hörbücher", icon: "headphones", x: 0.76, y: 0.44, size: geometry.size) { navigation.go(.library(.listen), room: .audio) }
                hotspot("Neuer Roman", icon: "doc.text.magnifyingglass", x: 0.54, y: 0.74, size: geometry.size) { navigation.go(.library(.analyze), room: .desk) }
            }
        }
    }
    private func hotspot(_ title: String, icon: String, x: CGFloat, y: CGFloat, size: CGSize, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.system(.subheadline, design: .serif)) }.buttonStyle(RomanButton()).frame(minWidth: 130, minHeight: 80).contentShape(Rectangle()).position(x: size.width * x, y: size.height * y)
    }
    private var mainMenu: some View {
        NavigationStack {
            List {
                Button("Start") { menu = false; navigation.go(.home, room: .salon) }
                Button("Bibliothek") { menu = false; navigation.go(.library(.library), room: .library) }
                Button("Lesen") { menu = false; navigation.go(.library(.read), room: .reading) }
                Button("Hörbücher") { menu = false; navigation.go(.library(.listen), room: .audio) }
                Button("Neuen Roman hinzufügen") { menu = false; importing = true }
                Button("Einstellungen") { menu = false; navigation.go(.settings, room: .settings) }
            }.navigationTitle("RomanVoice")
        }
    }
    private var importConfirmation: some View {
        NavigationStack {
            Form {
                if let document = imported {
                    Section("Diese Datei importieren?") {
                        LabeledContent("Datei", value: document.filename)
                        LabeledContent("Typ", value: (document.filename as NSString).pathExtension.uppercased())
                        LabeledContent("Größe", value: ByteCountFormatter.string(fromByteCount: Int64(document.original.count), countStyle: .file))
                        LabeledContent("Titel", value: document.title)
                        LabeledContent("Autor", value: document.author.isEmpty ? "Nicht angegeben" : document.author)
                        if document.cover != nil { Toggle("Erste PDF-Seite / Dokumentbild als Cover übernehmen", isOn: $useCover) }
                    }
                    Picker("Benötigte Downloads", selection: $network) { ForEach(NetworkPolicy.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    Text("Die Analyse läuft lokal. Die Netzwerkauswahl gilt für erforderliche Downloads. Importiere nur Inhalte, zu deren Nutzung du berechtigt bist.").font(.caption)
                    Button("Import bestätigen") { confirmImport(document) }
                }
            }.navigationTitle("Neuer Roman").toolbar { Button("Abbrechen") { imported = nil } }
        }
    }
    private func importFile(_ url: URL) {
        guard !loading else { return }; loading = true
        Task {
            do { imported = try await Task.detached { try DocumentImporter.read(url) }.value }
            catch { documentError = error.localizedDescription }
            loading = false
        }
    }
    private func confirmImport(_ document: ImportedDocument) {
        do {
            var book = Novel(title: document.title, author: document.author, sourceName: document.filename, text: document.text)
            book.network = network; book.spoilers = library.preferences.spoilers
            let filename = "original." + (document.filename as NSString).pathExtension.lowercased()
            try AppFiles.write(document.original, to: AppFiles.book(book.id).appendingPathComponent(filename))
            if useCover, let cover = document.cover {
                try AppFiles.write(cover, to: AppFiles.book(book.id).appendingPathComponent("cover.image"))
                book.coverFile = "cover.image"
            }
            book.sourceFile = filename; book.chapters = document.chapters; book.segments = TextStructure.segments(book.text, chapters: book.chapters)
            try library.save(book); imported = nil
            navigation.go(.analyze(book.id), room: .desk)
            if model.ready { work.analyze(book.id) }
        } catch { documentError = error.localizedDescription }
    }
}
