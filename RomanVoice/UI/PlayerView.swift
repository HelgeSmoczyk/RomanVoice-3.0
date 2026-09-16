import SwiftUI
import AVKit

struct PlayerView: View {
    let id: UUID
    @EnvironmentObject var library: Library
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var player: AudioPlayer
    @State private var switching = false
    @State private var chapters = false
    var body: some View {
        if let book = library.book(id) {
            VStack(spacing: 12) {
                PageHeader(title: "Hörbücher", subtitle: book.title) { navigation.go(.detail(id), room: .library) }
                GramophoneAnimation(playing: player.playing).frame(maxHeight: .infinity)
                RomanPanel {
                    VStack(spacing: 15) {
                        Text(book.title).font(.custom("EBGaramond-Regular", size: 27)).lineLimit(2)
                        if let error = player.error { Text(error).font(.caption); if player.waiting { ProgressView() } }
                        Slider(value: Binding(get: { min(player.elapsed, max(1, player.duration)) }, set: { player.seek($0) }), in: 0...max(1, player.duration))
                        HStack { Text(time(player.elapsed)); Spacer(); Text(time(player.duration)) }.font(.caption).monospacedDigit()
                        HStack(spacing: 22) {
                            Button { player.chapter(-1) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Vorheriges Kapitel")
                            Button { player.skip(-15) } label: { Image(systemName: "gobackward.15") }.accessibilityLabel("15 Sekunden zurück")
                            Button { player.toggle() } label: { Image(systemName: player.playing ? "pause.fill" : "play.fill").font(.largeTitle).frame(width: 58, height: 52) }.accessibilityLabel(player.playing ? "Pause" : "Wiedergabe")
                            Button { player.skip(15) } label: { Image(systemName: "goforward.15") }.accessibilityLabel("15 Sekunden vor")
                            Button { player.chapter(1) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Nächstes Kapitel")
                        }.font(.title2)
                        HStack {
                            Menu("\(book.playbackRate, specifier: "%.2g")×") { ForEach([Float(0.75), 1, 1.2, 1.5, 1.75, 2], id: \.self) { value in Button("\(value, specifier: "%.2g")×") { player.setRate(value) } } }
                            Spacer()
                            Menu { Button("Aus") { player.setSleep(0) }; ForEach([15, 30, 45, 60], id: \.self) { value in Button("\(value) Minuten") { player.setSleep(value) } }; Button("Ende des Kapitels") { player.setSleep(-1) } } label: { Label("Sleep", systemImage: player.sleepMinutes == 0 ? "moon" : "moon.fill") }
                            Spacer(); AudioRoutePicker().frame(width: 32, height: 32)
                        }
                        HStack {
                            Button { switching = true } label: { Label("⇄", systemImage: "headphones"); Image(systemName: "book") }
                            Spacer(); Button("Kapitel") { chapters = true }
                        }
                        if !book.segments.isEmpty && book.segments.contains(where: { $0.speaker == nil }) { Button("Offene Sprecherstelle klären") { navigation.go(.analyze(id), room: .desk) } }
                    }
                }.padding(.horizontal, 18).padding(.bottom, 12)
            }
            .onAppear { if player.bookID != id { player.open(id, autoplay: false) } }
            .confirmationDialog("Leseposition übernehmen?", isPresented: $switching) {
                Button("Übernehmen") { switchToRead(commit: true) }
                Button("Nur hier öffnen") { switchToRead(commit: false) }
                Button("Abbrechen", role: .cancel) {}
            }
            .sheet(isPresented: $chapters) {
                NavigationStack {
                    List(book.chapters) { chapter in Button(chapter.title) { player.open(id, offset: chapter.offset); chapters = false } }.navigationTitle("Kapitel").toolbar { Button("Fertig") { chapters = false } }
                }
            }
        }
    }
    private func switchToRead(commit: Bool) {
        player.persist()
        guard let book = library.book(id) else { return }
        let offset = TextStructure.sentenceStart(player.currentTextOffset ?? book.listening.offset, text: book.text)
        if commit { library.update(id) { $0.reading = Position(offset: offset) } }
        navigation.go(.reader(id, offset, !commit), room: .reading)
    }
    private func time(_ value: Double) -> String { let seconds = max(0, Int(value)); return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
}
struct AudioRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView { let view = AVRoutePickerView(); view.tintColor = .white; return view }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
