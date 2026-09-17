import SwiftUI
import AVFoundation

struct AnalysisView: View {
    let id: UUID

    @EnvironmentObject var library: Library
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var work: WorkCoordinator
    @EnvironmentObject var model: ModelManager

    var body: some View {
        if let book = library.book(id) {
            switch book.audioMode {
            case .audiobook:
                AudiobookSetupView(id: id)

            case .radioPlay:
    ConstructionView(
        title: "Hörspiel",
        subtitle: "Die Hörspiel-Analyse mit Qwen wird gerade neu aufgebaut."
    ) {
        navigation.go(.detail(id), room: .library)
    }

            case nil:
                LegacyAnalysisView(id: id)
            }
        }
    }
}

// MARK: - HÖRBUCH

private struct AudiobookSetupView: View {
    let id: UUID

    @EnvironmentObject var library: Library
    @EnvironmentObject var navigation: Navigation
    @EnvironmentObject var work: WorkCoordinator

    @State private var synthesizer =
        AVSpeechSynthesizer()

    var body: some View {
        if let book = library.book(id) {
            VStack(spacing: 12) {
                PageHeader(
                    title: "Hörbuch",
                    subtitle:
                        "Eine Stimme liest den gesamten Text."
                ) {
                    navigation.go(
                        .detail(id),
                        room: .library
                    )
                }

                WorkAnimation(
                    active:
                        work.activeID == id,
                    rendering:
                        book.phase == .rendering
                )
                .frame(height: 180)

                ScrollView {
                    RomanPanel {
                        VStack(
                            alignment: .leading,
                            spacing: 16
                        ) {
                            Text(book.sourceName)
                                .font(.headline)

                            Text(status(book))
                                .font(.subheadline)

                            ProgressView(
                                value:
                                    book.audioProgress
                            )

                            Text(
                                "Audio: \(Int(book.audioProgress * 100)) %"
                            )
                            .font(.caption)

                            if let error =
                                book.error {
                                Text(error)
                                    .foregroundStyle(
                                        .orange
                                    )
                            }

                            Divider()

                            Text("Hörbuchstimme")
                                .font(.headline)

                            Text(
                                "Für diesen Modus wird keine KI-Analyse benötigt."
                            )
                            .font(.caption)

                            voicePicker(book)

                            pitchPicker(book)

                            tempoPicker(book)

                            Button(
                                "Stimme probehören"
                            ) {
                                preview(book)
                            }
                            .buttonStyle(
                                RomanButton()
                            )
                            .disabled(
                                narratorVoice(book)
                                    == nil
                            )

                            Divider()

                            if work.activeID == id {
                                Button("Pausieren") {
                                    work.stop(
                                        explicit: false
                                    )
                                }
                                .buttonStyle(
                                    RomanButton()
                                )

                                Button(
                                    "Erstellung abbrechen",
                                    role: .destructive
                                ) {
                                    work.stop(
                                        explicit: true
                                    )
                                }
                                .foregroundStyle(.red)

                            } else {
                                Button(
                                    book.audioProgress > 0
                                    ? "Hörbuch fortsetzen"
                                    : "Hörbuch erstellen"
                                ) {
                                    confirmAndRender(book)
                                }
                                .buttonStyle(
                                    RomanButton(
                                        prominent: true
                                    )
                                )
                                .disabled(
                                    narratorVoice(book)
                                        == nil
                                )

                                if book.phase == .paused ||
                                    book.phase == .failed {

                                    Button(
                                        "Gespeicherten Auftrag fortsetzen"
                                    ) {
                                        work.resume(id)
                                    }
                                    .buttonStyle(
                                        RomanButton()
                                    )
                                }
                            }

                            if book.hasAudio {
                                Button(
                                    "Jetzt hören"
                                ) {
                                    navigation.go(
                                        .player(id),
                                        room: .audio
                                    )
                                }
                                .buttonStyle(
                                    RomanButton()
                                )
                            }

                            Divider()

                            Text(
                                "\(book.chapters.count) Kapitel · \(book.segments.count) Abschnitte"
                            )
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                }
            }
            
            .onDisappear {
                synthesizer.stopSpeaking(
                    at: .immediate
                )
            }
        }
    }

    private func voicePicker(
        _ book: Novel
    ) -> some View {
        Picker(
            "Grundstimme",
            selection: Binding(
                get: {
                    narratorVoice(book)?
                        .identifier ?? ""
                },
                set: { identifier in
                    guard !identifier.isEmpty
                    else {
                        return
                    }

                    var choice =
                        narratorVoice(book)
                        ?? VoiceChoice(
                            identifier:
                                identifier
                        )

                    choice.identifier =
                        identifier

                    work.setAudiobookVoice(
                        id,
                        choice: choice
                    )
                }
            )
        ) {
            Text("Bitte auswählen")
                .tag("")

            ForEach(
                VoiceCatalog.available,
                id: \.identifier
            ) { voice in
                Text(voice.name)
                    .tag(voice.identifier)
            }
        }
    }

    private func pitchPicker(
        _ book: Novel
    ) -> some View {
        Picker(
            "Tonhöhe",
            selection: Binding(
                get: {
                    narratorVoice(book)?
                        .pitch ?? 1
                },
                set: { value in
                    guard var choice =
                            narratorVoice(book)
                    else {
                        return
                    }

                    choice.pitch = value

                    work.setAudiobookVoice(
                        id,
                        choice: choice
                    )
                }
            )
        ) {
            Text("Tief")
                .tag(Float(0.8))

            Text("Normal")
                .tag(Float(1))

            Text("Hoch")
                .tag(Float(1.2))
        }
    }

    private func tempoPicker(
        _ book: Novel
    ) -> some View {
        Picker(
            "Tempo",
            selection: Binding(
                get: {
                    narratorVoice(book)?
                        .tempo ?? 1
                },
                set: { value in
                    guard var choice =
                            narratorVoice(book)
                    else {
                        return
                    }

                    choice.tempo = value

                    work.setAudiobookVoice(
                        id,
                        choice: choice
                    )
                }
            )
        ) {
            Text("Langsam")
                .tag(Float(0.85))

            Text("Normal")
                .tag(Float(1))

            Text("Schnell")
                .tag(Float(1.15))
        }
    }

    private func narratorVoice(
        _ book: Novel
    ) -> VoiceChoice? {
        book.characters
            .first(where: { $0.isNarrator })?
            .voice
    }

    private func preview(
        _ book: Novel
    ) {
        guard let choice =
                narratorVoice(book)
        else {
            return
        }

        do {
            synthesizer.stopSpeaking(
                at: .immediate
            )

            let utterance =
                try VoiceCatalog.utterance(
                    "Eine neue Geschichte beginnt. Hörst du meine Stimme?",
                    choice: choice
                )

            synthesizer.speak(utterance)

        } catch {
            library.error =
                error.localizedDescription
        }
    }

    private func confirmAndRender(
        _ book: Novel
    ) {
        guard let choice =
                narratorVoice(book)
        else {
            library.error =
                "Bitte zuerst eine Stimme auswählen."
            return
        }

        work.setAudiobookVoice(
            id,
            choice: choice
        )

        work.render(id)
    }

    private func status(
        _ book: Novel
    ) -> String {
        if work.activeID == id {
            return work.activity
        }

        switch book.phase {
        case .imported:
            return "Bereit zur Stimmenauswahl"

        case .analyzing:
            return "Vorbereitung"

        case .review:
            return "Stimme auswählen"

        case .rendering:
            return "Hörbuch wird erstellt"

        case .ready:
            return "Vollständig offline verfügbar"

        case .paused:
            return "Pausiert"

        case .cancelled:
            return "Bewusst abgebrochen"

        case .failed:
            return "Unterbrochen – Checkpoint vorhanden"
        }
    }
}



// MARK: - ALTE WERKE OHNE MODUS

private struct LegacyAnalysisView: View {
    let id: UUID

    @EnvironmentObject var library: Library
    @EnvironmentObject var navigation: Navigation

    var body: some View {
        VStack(spacing: 20) {
            PageHeader(
                title: "Hörmodus wählen",
                subtitle:
                    "Dieses Werk stammt aus einer älteren RomanVoice-Version."
            ) {
                navigation.go(
                    .detail(id),
                    room: .library
                )
            }

            Spacer()

            RomanPanel {
                VStack(spacing: 18) {
                    Text(
                        "Wie möchtest du diesen Text hören?"
                    )
                    .font(.headline)

                    Button("Hörbuch") {
                        library.update(id) {
                            $0.audioMode =
                                .audiobook
                            $0.phase = .review
                            $0.explicitStop =
                                false
                        }
                    }
                    .buttonStyle(
                        RomanButton(
                            prominent: true
                        )
                    )

                    Button("Hörspiel") {
                        library.update(id) {
                            $0.audioMode =
                                .radioPlay
                            $0.phase = .imported
                            $0.explicitStop =
                                false
                        }
                    }
                    .buttonStyle(
                        RomanButton()
                    )
                }
                .padding()
            }
            .padding(.horizontal, 18)

            Spacer()
        }
    }
}
