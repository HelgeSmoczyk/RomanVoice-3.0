import SwiftUI

// MARK: - Navigation

enum Screen: Equatable {
    case home
    case library(Intent)
    case detail(UUID)
    case analyze(UUID)
    case reader(UUID, Int?, Bool)
    case player(UUID)
    case settings
    case room(RomanVoiceRoom)
}

enum RomanVoiceRoom: String, Equatable, CaseIterable {
    case library = "BIBLIOTHEK"
    case reading = "LESEN"
    case listening = "HÖREN"
    case importing = "IMPORTIEREN"

    var buttonAsset: String {
        switch self {
        case .library: return "RomanVoice_Icon_Bibliothek"
        case .reading: return "RomanVoice_Icon_Lesen"
        case .listening: return "RomanVoice_Icon_Hoeren"
        case .importing: return "RomanVoice_Icon_Importieren"
        }
    }

    var buttonTitle: String {
        switch self {
        case .library: return "Bibliothek"
        case .reading: return "Lesen"
        case .listening: return "Hören"
        case .importing: return "Importieren"
        }
    }
}

@MainActor
final class Navigation: ObservableObject {
    @Published var screen: Screen = .home
    @Published var room: Room = .salon

    func go(_ screen: Screen, room: Room = .salon) {
        withAnimation(.easeInOut(duration: 0.35)) {
            self.room = room
            self.screen = screen
        }
    }

    func goHome() {
        go(.home, room: .salon)
    }

    func goToRoom(_ destination: RomanVoiceRoom) {
        go(.room(destination), room: .salon)
    }
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject private var navigation: Navigation

    @State private var showMenu = false
    @State private var showImprint = false

    var body: some View {
        ZStack {
            switch navigation.screen {
            case .home:
                RomanVoiceStartScreen(
                    showMenu: $showMenu,
                    showImprint: $showImprint
                )

            case .room(let destination):
                RomanVoiceDeadEndScreen(destination: destination)

            case .settings:
                SettingsView()

            // Die vorhandenen Programmteile bleiben kompilierbar,
            // werden auf diesem ersten Startplatz aber bewusst noch nicht benutzt.
            case .library, .detail, .analyze, .reader, .player:
                RomanVoiceDeadEndScreen(destination: .library)
            }
        }
        .sheet(isPresented: $showMenu) {
            RomanVoiceMenu(showMenu: $showMenu)
        }
        .sheet(isPresented: $showImprint) {
            RomanVoiceImprint(showImprint: $showImprint)
        }
        .foregroundStyle(RomanStyle.cream)
        .tint(RomanStyle.gold)
    }
}

// MARK: - Startplatz

private struct RomanVoiceStartScreen: View {
    @EnvironmentObject private var navigation: Navigation

    @Binding var showMenu: Bool
    @Binding var showImprint: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                salonBackground

                // RomanVoice-Logo im Fensterbereich.
                Image("RomanVoiceLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(geometry.size.width * 0.62, 310))
                    .position(
                        x: geometry.size.width * 0.50,
                        y: geometry.size.height * 0.18
                    )
                    .accessibilityHidden(true)

                // Die vier funktionalen Schaltflächen.
                roomButton(.library, x: 0.22, y: 0.34, size: geometry.size)
                roomButton(.reading, x: 0.25, y: 0.59, size: geometry.size)
                roomButton(.listening, x: 0.77, y: 0.48, size: geometry.size)
                roomButton(.importing, x: 0.58, y: 0.76, size: geometry.size)

                // Hamburger und Einstellungen.
                VStack {
                    HStack {
                        Button {
                            showMenu = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 24, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(RomanGlassButton())
                        .accessibilityLabel("Menü")

                        Spacer()

                        Button {
                            navigation.go(.settings, room: .settings)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 23, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(RomanGlassButton())
                        .accessibilityLabel("Einstellungen")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    Spacer()

                    Button("Impressum") {
                        showImprint = true
                    }
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(RomanStyle.cream)
                    .shadow(color: .black, radius: 4)
                    .padding(.bottom, 10)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var salonBackground: some View {
        Image("Salon")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private func roomButton(
        _ destination: RomanVoiceRoom,
        x: CGFloat,
        y: CGFloat,
        size: CGSize
    ) -> some View {
        Button {
            navigation.goToRoom(destination)
        } label: {
            Image(destination.buttonAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.buttonTitle)
        .position(x: size.width * x, y: size.height * y)
    }
}

// MARK: - Vier Sackgassen

private struct RomanVoiceDeadEndScreen: View {
    @EnvironmentObject private var navigation: Navigation

    let destination: RomanVoiceRoom

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // In jeder Sackgasse exakt derselbe Salon – ohne Start-Schaltflächen.
                Image("Salon")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                // Raumname an derselben Stelle wie das RomanVoice-Logo.
                RomanVoiceRoomLogo(title: destination.rawValue)
                    .frame(width: min(geometry.size.width * 0.76, 350))
                    .position(
                        x: geometry.size.width * 0.50,
                        y: geometry.size.height * 0.18
                    )

                VStack {
                    HStack {
                        Button {
                            navigation.goHome()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(RomanGlassButton())
                        .accessibilityLabel("Zurück zum Start")

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Raumname im Stil des RomanVoice-Logos

private struct RomanVoiceRoomLogo: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.custom("EBGaramond-Regular", size: 39))
            .fontWeight(.semibold)
            .tracking(2.2)
            .minimumScaleFactor(0.55)
            .lineLimit(1)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        RomanStyle.cream,
                        RomanStyle.gold,
                        RomanStyle.cream
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: .black.opacity(0.95), radius: 2, x: 0, y: 2)
            .shadow(color: RomanStyle.gold.opacity(0.35), radius: 5)
            .padding(.horizontal, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Kleine transparente Bedienelemente

private struct RomanGlassButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(RomanStyle.cream)
            .background(
                Circle()
                    .fill(Color.black.opacity(configuration.isPressed ? 0.48 : 0.28))
            )
            .overlay(
                Circle()
                    .stroke(RomanStyle.gold.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.65), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
    }
}

// MARK: - Hamburger-Menü

private struct RomanVoiceMenu: View {
    @EnvironmentObject private var navigation: Navigation
    @Binding var showMenu: Bool

    var body: some View {
        NavigationStack {
            List {
                Button("Start") {
                    showMenu = false
                    navigation.goHome()
                }

                ForEach(RomanVoiceRoom.allCases, id: \.self) { destination in
                    Button(destination.buttonTitle) {
                        showMenu = false
                        navigation.goToRoom(destination)
                    }
                }

                Button("Einstellungen") {
                    showMenu = false
                    navigation.go(.settings, room: .settings)
                }
            }
            .navigationTitle("RomanVoice")
        }
    }
}

// MARK: - Impressum

private struct RomanVoiceImprint: View {
    @Binding var showImprint: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                RomanStyle.green.ignoresSafeArea()

                VStack(spacing: 18) {
                    Text("Impressum")
                        .font(.custom("EBGaramond-Regular", size: 34))
                        .foregroundStyle(RomanStyle.gold)

                    Text("RomanVoice 3.0")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(RomanStyle.cream)

                    Text("Die vollständigen Impressumsangaben werden hier später eingesetzt.")
                        .font(.system(.footnote, design: .serif))
                        .foregroundStyle(RomanStyle.cream.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    Spacer()
                }
                .padding(.top, 35)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        showImprint = false
                    }
                }
            }
        }
    }
}
