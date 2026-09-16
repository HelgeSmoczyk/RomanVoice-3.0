import SwiftUI

@main @MainActor struct RomanVoiceApp: App {
    @StateObject private var library: Library
    @StateObject private var model: ModelManager
    @StateObject private var work: WorkCoordinator
    @StateObject private var player: AudioPlayer
    @StateObject private var navigation = Navigation()
    init() {
        let library = Library(), model = ModelManager()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test") && !library.books.contains(where: { $0.title == "RomanVoice Prüfbuch" }) {
            var sample = Novel(title: "RomanVoice Prüfbuch", sourceName: "pruefung.txt", text: "Kapitel 1\n" + String(repeating: "Der grüne Sessel stand am Fenster. Ein neues Buch wartete auf dem Schreibtisch. ", count: 100) + "\nKapitel 2\nDie Geschichte geht weiter.")
            sample.chapters = TextStructure.chapters(sample.text)
            sample.segments = TextStructure.segments(sample.text, chapters: sample.chapters)
            try? library.save(sample)
        }
        #endif
        _library = StateObject(wrappedValue: library)
        _model = StateObject(wrappedValue: model)
        _work = StateObject(wrappedValue: WorkCoordinator(library: library, model: model))
        _player = StateObject(wrappedValue: AudioPlayer(library: library))
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(library).environmentObject(model).environmentObject(work).environmentObject(player).environmentObject(navigation)
        }
    }
}
