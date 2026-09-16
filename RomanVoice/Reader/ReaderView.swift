import SwiftUI

struct ReaderView: View {
    let id: UUID
    var initialOffset: Int?
    var preservePosition: Bool
    @EnvironmentObject var library: Library
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var player: AudioPlayer
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var layout: BookLayout?
    @State private var page = 0
    @State private var zoom: Double = 1
    @State private var controls = true
    @State private var chapters = false
    @State private var switching = false
    @State private var flight: CGFloat = 0
    @State private var lastActivity = Date()
    @State private var interacted = false
    @State private var currentOffset = 0
    @State private var hideTask: Task<Void, Never>?
    private let clock = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    var body: some View {
        ZStack {
            if let layout {
                GeometryReader { geometry in
                    PageViewport(layout: layout, page: $page, zoom: $zoom, mode: library.preferences.readingMode, dark: scheme == .dark, activity: { interacted = true; activity() }, tap: toggleControls, visibleOffset: { offset in currentOffset = offset; if interacted { library.update(id) { $0.reading.offset = offset } } })
                        .accessibilityIdentifier("reader.viewport")
                        .scaleEffect(0.12 + 0.88 * flight)
                        .rotation3DEffect(.degrees(Double((1 - flight) * 72)), axis: (x: 0, y: 1, z: 0), anchor: .leading)
                        .offset(x: (1 - flight) * -geometry.size.width * 0.24, y: (1 - flight) * geometry.size.height * 0.25)
                        .allowsHitTesting(flight == 1)
                }
                if flight < 1 { AtlasSprite(index: 0).frame(width: 150, height: 150).opacity(1 - flight).rotation3DEffect(.degrees(Double(flight * -150)), axis: (x: 0, y: 1, z: 0)) }
                if controls && flight == 1 {
                    VStack {
                        HStack {
                            Menu {
                                Button("Kapitelübersicht") { chapters = true; activity() }
                                Button("Zur Bibliothek") { navigation.go(.library(.read), room: .library) }
                                Button("Zum Hauptmenü") { navigation.go(.home, room: .salon) }
                            } label: { Image(systemName: "line.3.horizontal").padding(14).background(RomanStyle.green, in: Circle()) }
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Button { activity(); switching = true } label: { Label("⇄", systemImage: "book"); Image(systemName: "headphones") }.buttonStyle(RomanButton())
                            Spacer()
                            Text("Seite \(page + 1) von \(layout.pages.count)").font(.caption).padding(8).background(RomanStyle.green, in: Capsule())
                        }
                    }.padding(12)
                }
                if controls && library.preferences.readingMode == .buttons && flight == 1 {
                    VStack { HStack { Button { interacted = true; page = max(0, page - 1); activity() } label: { Image(systemName: "chevron.left").padding(12) }.buttonStyle(RomanButton()); Spacer() }; Spacer(); HStack { Spacer(); Button { interacted = true; page = min(layout.pages.count - 1, page + 1); activity() } label: { Image(systemName: "chevron.right").padding(12) }.buttonStyle(RomanButton()) } }.padding(.vertical, 70).padding(.horizontal, 8)
                }
            } else { ProgressView("Buch wird gesetzt …") }
        }
        .task {
            guard let book = library.book(id) else { return }
            let value = BookLayout(book: book); layout = value; page = value.page(at: initialOffset ?? book.reading.offset); zoom = book.zoom
            currentOffset = initialOffset ?? book.reading.offset
            if let offset = initialOffset, !preservePosition { library.update(id) { $0.reading.offset = offset } }
            if !preservePosition { library.update(id) { $0.reading.started = true } }
            activity()
            withAnimation(.easeInOut(duration: reduceMotion ? 0 : 1.8)) { flight = 1 }
            hideTask = Task { try? await Task.sleep(for: .seconds(5)); if !Task.isCancelled { controls = false } }
        }
        .onChange(of: page) { old, new in
            guard old != new, interacted, flight == 1, let layout else { return }
            currentOffset = layout.pages[new].offset
            library.update(id) { $0.reading.offset = layout.pages[new].offset; $0.reading.completed = new == layout.pages.count - 1; $0.modified = Date() }
            activity()
        }
        .onChange(of: zoom) { _, value in library.update(id) { $0.zoom = value }; activity() }
        .onReceive(clock) { _ in UIApplication.shared.isIdleTimerDisabled = Date().timeIntervalSince(lastActivity) < 900 }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; hideTask?.cancel() }
        .confirmationDialog("Hörposition übernehmen?", isPresented: $switching) {
            Button("Übernehmen") { switchToAudio(commit: true) }
            Button("Nur hier öffnen") { switchToAudio(commit: false) }
            Button("Abbrechen", role: .cancel) {}
        }
        .sheet(isPresented: $chapters) {
            NavigationStack {
                List {
                    if let book = library.book(id), let layout {
                        if book.chapters.isEmpty { Text("Keine Kapitelüberschriften vorhanden.") }
                        ForEach(book.chapters) { chapter in
                            Button { interacted = true; page = layout.page(at: chapter.offset); chapters = false; activity() } label: { HStack { Text(chapter.title); Spacer(); Text("\(layout.page(at: chapter.offset) + 1)") } }
                        }
                    }
                }.navigationTitle("Inhalt").toolbar { Button("Fertig") { chapters = false } }
            }
        }
    }
    private func activity() { lastActivity = Date(); UIApplication.shared.isIdleTimerDisabled = true }
    private func toggleControls() {
        controls.toggle(); hideTask?.cancel()
        if controls { hideTask = Task { try? await Task.sleep(for: .seconds(5)); if !Task.isCancelled { controls = false } } }
    }
    private func switchToAudio(commit: Bool) {
        guard let book = library.book(id), layout != nil else { return }
        let offset = TextStructure.sentenceStart(currentOffset, text: book.text)
        if commit { library.update(id) { $0.listening = Position(offset: offset) } }
        player.open(id, offset: offset, autoplay: commit)
        navigation.go(.player(id), room: .audio)
    }
}
