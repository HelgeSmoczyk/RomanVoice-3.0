import SwiftUI
import UniformTypeIdentifiers

enum Screen: Equatable {
    case home
    case library(Intent)
    case detail(UUID)
    case analyze(UUID)
    case reader(UUID, Int?, Bool)
    case player(UUID)
    case settings
}

@MainActor final class Navigation: ObservableObject {
    @Published var screen: Screen = .home
    @Published var room: Room = .salon

    func go(_ screen: Screen, room: Room) {
        withAnimation(.easeInOut(duration: 0.8)) {
            self.room = room
            self.screen = screen
        }
    }
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
    @State private var selectedMode: AudioMode?

    var body: some View {
        ZStack {
            SceneBackdrop(room: navigation.room)

            Group {
                switch navigation.screen {
                case .home:
                    salon

                case .library(let intent):
                    LibraryView(
                        intent: intent,
                        importAction: {
                            importing = true
                        }
                    )

                case .detail(let id):
                    BookDetailView(id: id)

                case .analyze(let id):
                    AnalysisView(id: id)

                case .reader(let id, let offset, let preserve):
                    ReaderView(
                        id: id,
                        initialOffset: offset,
                        preservePosition: preserve
                    )
                    .id("\(id)-\(offset ?? -1)-\(preserve)")

                case .player(let id):
                    PlayerView(id: id)

                case .settings:
                    SettingsView()
                }
            }
            .transition(.opacity)

            if loading {
                ProgressView("Datei wird gelesen …")
                    .padding(25)
                    .background(
                        RomanStyle.green,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }
        }
        .foregroundStyle(RomanStyle.cream)
        .tint(RomanStyle.gold)

        .sheet(isPresented: $menu) {
            mainMenu
                .presentationDetents([.medium, .large])
        }

        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [
                .pdf,
                .plainText,
                UTType(filenameExtension: "docx") ?? .data
            ]
        ) { result in
            switch result {
            case .success(let url):
                importFile(url)

            case .failure(let error):
                documentError = error.localizedDescription
            }
        }

        .sheet(
            isPresented: Binding(
                get: {
                    imported != nil
                },
                set: {
                    if !$0 {
                        imported = nil
                        selectedMode = nil
                    }
                }
            )
        ) {
            importConfirmation
        }

        .alert(
            "RomanVoice",
            isPresented: Binding(
                get: {
                    documentError != nil ||
                    library.error != nil
                },
                set: {
                    if !$0 {
                        documentError = nil
                        library.error = nil
                    }
                }
            )
        ) {
            Button("OK") {
                documentError = nil
                library.error = nil
            }
        } message: {
            Text(
                documentError ??
                library.error ??
                ""
            )
        }

        .onOpenURL {
            importFile($0)
        }

        .onDrop(
            of: [.fileURL],
            isTargeted: nil
        ) { providers in
            guard let provider = providers.first else {
                return false
            }

            _ = provider.loadDataRepresentation(
                forTypeIdentifier:
                    UTType.fileURL.identifier
            ) { data, _ in
                guard
                    let data,
                    let url = URL(
                        dataRepresentation: data,
                        relativeTo: nil
                    )
                else {
                    return
                }

                Task { @MainActor in
                    importFile(url)
                }
            }

            return true
        }

        .onChange(of: phase) { _, value in
            if value == .background {
                work.setForeground(false)
                player.persist()
            }

            if value == .active {
                work.setForeground(true)
            }
        }

        .onChange(of: model.ready) { _, ready in
            if ready {
                work.resumeAutomatic()
            }
        }

        .task {
            work.audioChanged = {
                player.availableAudioChanged()
            }
        }
    }

    private var salon: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    HStack {
                        Button {
                            menu = true
                        } label: {
                            Image(
                                systemName:
                                    "line.3.horizontal"
                            )
                            .frame(
                                width: 44,
                                height: 44
                            )
                        }
                        .buttonStyle(RomanButton())

                        Spacer()

                        Button {
                            navigation.go(
                                .settings,
                                room: .settings
                            )
                        } label: {
                            Image(
                                systemName:
                                    "gearshape"
                            )
                            .frame(
                                width: 44,
                                height: 44
                            )
                        }
                        .buttonStyle(RomanButton())
                    }

                    Spacer()

                    HStack {
                        Button("Impressum") {
                            navigation.go(
                                .settings,
                                room: .settings
                            )
                        }

                        Text("·")

                        Button("Datenschutz") {
                            navigation.go(
                                .settings,
                                room: .settings
                            )
                        }

                        Text("· 3.0")
                    }
                    .font(.caption2)
                    .shadow(radius: 5)
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 8)

                hotspot(
                    "Bibliothek",
                    icon: "books.vertical",
                    x: 0.22,
                    y: 0.28,
                    size: geometry.size
                ) {
                    navigation.go(
                        .library(.library),
                        room: .library
                    )
                }

                hotspot(
                    "Lesen",
                    icon: "book",
                    x: 0.24,
                    y: 0.55,
                    size: geometry.size
                ) {
                    navigation.go(
                        .library(.read),
                        room: .reading
                    )
                }

                hotspot(
                    "Hörbücher",
                    icon: "headphones",
                    x: 0.76,
                    y: 0.44,
                    size: geometry.size
                ) {
                    navigation.go(
                        .library(.listen),
                        room: .audio
                    )
                }

                hotspot(
                    "Neuer Roman",
                    icon:
                        "doc.text.magnifyingglass",
                    x: 0.54,
                    y: 0.74,
                    size: geometry.size
                ) {
                    navigation.go(
                        .library(.analyze),
                        room: .desk
                    )
                }
            }
        }
    }

    private func hotspot(
        _ title: String,
        icon: String,
        x: CGFloat,
        y: CGFloat,
        size: CGSize,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(
                title,
                systemImage: icon
            )
            .font(
                .system(
                    .subheadline,
                    design: .serif
                )
            )
        }
        .buttonStyle(RomanButton())
        .frame(
            minWidth: 130,
            minHeight: 80
        )
        .contentShape(Rectangle())
        .position(
            x: size.width * x,
            y: size.height * y
        )
    }

    private var mainMenu: some View {
        NavigationStack {
            List {
                Button("Start") {
                    menu = false
                    navigation.go(
                        .home,
                        room: .salon
                    )
                }

                Button("Bibliothek") {
                    menu = false
                    navigation.go(
                        .library(.library),
                        room: .library
                    )
                }

                Button("Lesen") {
                    menu = false
                    navigation.go(
                        .library(.read),
                        room: .reading
                    )
                }

                Button("Hörbücher") {
                    menu = false
                    navigation.go(
                        .library(.listen),
                        room: .audio
                    )
                }

                Button(
                    "Neuen Roman hinzufügen"
                ) {
                    menu = false
                    importing = true
                }

                Button("Einstellungen") {
                    menu = false
                    navigation.go(
                        .settings,
                        room: .settings
                    )
                }
            }
            .navigationTitle("RomanVoice")
        }
    }

    private var importConfirmation: some View {
        NavigationStack {
            Form {
                if let document = imported {
                    Section(
                        "Diese Datei importieren?"
                    ) {
                        LabeledContent(
                            "Datei",
                            value:
                                document.filename
                        )

                        LabeledContent(
                            "Typ",
                            value:
                                (document.filename
                                    as NSString)
                                .pathExtension
                                .uppercased()
                        )

                        LabeledContent(
                            "Größe",
                            value:
                                ByteCountFormatter
                                .string(
                                    fromByteCount:
                                        Int64(
                                            document
                                                .original
                                                .count
                                        ),
                                    countStyle:
                                        .file
                                )
                        )

                        LabeledContent(
                            "Titel",
                            value: document.title
                        )

                        LabeledContent(
                            "Autor",
                            value:
                                document.author
                                    .isEmpty
                                ? "Nicht angegeben"
                                : document.author
                        )

                        if document.cover != nil {
                            Toggle(
                                "Erste PDF-Seite / Dokumentbild als Cover übernehmen",
                                isOn: $useCover
                            )
                        }
                    }

                    Section(
                        "Wie möchtest du diesen Text hören?"
                    ) {
                        Button {
                            selectedMode = .audiobook
                        } label: {
                            modeRow(
                                title: "Hörbuch",
                                subtitle:
                                    "Eine Stimme liest den gesamten Text. Keine Figuren- oder Dialoganalyse.",
                                icon: "headphones",
                                selected:
                                    selectedMode ==
                                    .audiobook
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            selectedMode = .radioPlay
                        } label: {
                            modeRow(
                                title: "Hörspiel",
                                subtitle:
                                    "Figuren, Dialoge und Sprecher werden mit der lokalen KI analysiert.",
                                icon:
                                    "person.3.fill",
                                selected:
                                    selectedMode ==
                                    .radioPlay
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Picker(
                        "Benötigte Downloads",
                        selection: $network
                    ) {
                        ForEach(
                            NetworkPolicy.allCases,
                            id: \.self
                        ) {
                            Text($0.rawValue)
                                .tag($0)
                        }
                    }

                    if selectedMode == .audiobook {
                        Text(
                            "Für ein Hörbuch wird keine KI-Analyse benötigt. Kapitel und Überschriften bleiben für Navigation und Fortschritt erhalten."
                        )
                        .font(.caption)
                    } else if selectedMode == .radioPlay {
                        Text(
                            "Für ein Hörspiel wird die lokale KI zur Figuren- und Dialoganalyse verwendet."
                        )
                        .font(.caption)
                    }

                    Text(
                        "Die Verarbeitung erfolgt lokal. Die Netzwerkauswahl gilt nur für erforderliche Downloads. Importiere nur Inhalte, zu deren Nutzung du berechtigt bist."
                    )
                    .font(.caption)

                    Button("Import bestätigen") {
                        confirmImport(document)
                    }
                    .disabled(
                        selectedMode == nil
                    )
                }
            }
            .navigationTitle("Neuer Roman")
            .toolbar {
                Button("Abbrechen") {
                    imported = nil
                    selectedMode = nil
                }
            }
        }
    }

    private func modeRow(
        title: String,
        subtitle: String,
        icon: String,
        selected: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(
                systemName:
                    selected
                    ? "checkmark.circle.fill"
                    : "circle"
            )
        }
        .contentShape(Rectangle())
        .padding(.vertical, 5)
    }

    private func importFile(_ url: URL) {
        guard !loading else {
            return
        }

        loading = true
        selectedMode = nil

        Task {
            do {
                imported =
                    try await Task.detached {
                        try DocumentImporter.read(
                            url
                        )
                    }.value
            } catch {
                documentError =
                    error.localizedDescription
            }

            loading = false
        }
    }

    private func confirmImport(
        _ document: ImportedDocument
    ) {
        guard let selectedMode else {
            documentError =
                "Bitte Hörbuch oder Hörspiel auswählen."
            return
        }

        do {
            var book = Novel(
                title: document.title,
                author: document.author,
                sourceName:
                    document.filename,
                text: document.text
            )

            book.audioMode = selectedMode
            book.network = network
            book.spoilers =
                library.preferences.spoilers

            let filename =
                "original." +
                (document.filename as NSString)
                    .pathExtension
                    .lowercased()

            try AppFiles.write(
                document.original,
                to:
                    AppFiles.book(book.id)
                    .appendingPathComponent(
                        filename
                    )
            )

            if useCover,
               let cover = document.cover {
                try AppFiles.write(
                    cover,
                    to:
                        AppFiles.book(book.id)
                        .appendingPathComponent(
                            "cover.image"
                        )
                )

                book.coverFile =
                    "cover.image"
            }

            book.sourceFile = filename
            book.chapters =
                document.chapters

            if book.chapters.isEmpty {
                book.chapters =
                    TextStructure.chapters(
                        book.text
                    )
            }

            book.segments =
                TextStructure.segments(
                    book.text,
                    chapters: book.chapters
                )

            if selectedMode == .audiobook {
                prepareAudiobook(&book)
            }

            try library.save(book)

            imported = nil
            self.selectedMode = nil

            navigation.go(
                .analyze(book.id),
                room: .desk
            )

            // Hörspiel startet bewusst NICHT
            // automatisch. Der Nutzer startet
            // die KI-Analyse im Analysebereich.
            //
            // Hörbuch benötigt Qwen überhaupt nicht.
        } catch {
            documentError =
                error.localizedDescription
        }
    }

    private func prepareAudiobook(
        _ book: inout Novel
    ) {
        for index in book.segments.indices {
            book.segments[index].speaker =
                "Erzähler"

            book.segments[index].dialogue =
                false

            book.segments[index].analyzed =
                true

            book.segments[index].error =
                nil
        }

        var narrator =
            book.characters.first {
                $0.isNarrator
            }
            ?? CharacterRole(
                name: "Erzähler",
                isNarrator: true
            )

        narrator.name = "Erzähler"
        narrator.isNarrator = true
        narrator.appearances =
            book.segments.count

        book.characters = [narrator]
        book.phase = .review
        book.interruptedPhase = nil
        book.explicitStop = false
        book.voicesConfirmed = false
    }
}
