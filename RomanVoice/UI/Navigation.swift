import SwiftUI
import UniformTypeIdentifiers

// MARK: - RomanVoice Navigation

struct RomanVoiceNavigationView: View {

    var body: some View {
        NavigationStack {
            RomanVoiceStartView()
        }
    }
}


// MARK: - Startplatz / Salon

struct RomanVoiceStartView: View {

    var body: some View {
        ZStack {

            // Salon als vollflächiger Hintergrund
            Image("Salon")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {

                // MARK: Oberer Bereich

                HStack {

                    // Hamburger
                    Button {
                        // Funktion kommt später
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Menü")
                    .accessibilityIdentifier("Menü")

                    Spacer()

                    // Einstellungen
                    Button {
                        // Funktion kommt später
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Einstellungen")
                    .accessibilityIdentifier("Einstellungen")
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                // MARK: RomanVoice Logo

                Image("RomanVoiceLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 270)
                    .padding(.top, 8)
                    .accessibilityHidden(true)

                Spacer()

                // MARK: Vier Hauptwege

                HStack(alignment: .bottom, spacing: 10) {

                    NavigationLink {
                        RomanVoiceRoomView(
                            roomName: "BIBLIOTHEK"
                        )
                    } label: {
                        RomanVoiceRouteButton(
                            imageName: "ButtonBibliothek",
                            title: "Bibliothek"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Bibliothek")
                    .accessibilityIdentifier("Bibliothek")


                    NavigationLink {
                        RomanVoiceRoomView(
                            roomName: "LESEN"
                        )
                    } label: {
                        RomanVoiceRouteButton(
                            imageName: "ButtonLesen",
                            title: "Lesen"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Lesen")
                    .accessibilityIdentifier("Lesen")


                    NavigationLink {
                        RomanVoiceRoomView(
                            roomName: "HÖREN"
                        )
                    } label: {
                        RomanVoiceRouteButton(
                            imageName: "ButtonHoeren",
                            title: "Hören"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hören")
                    .accessibilityIdentifier("Hören")


                    NavigationLink {
                        RomanVoiceRoomView(
                            roomName: "IMPORTIEREN"
                        )
                    } label: {
                        RomanVoiceRouteButton(
                            imageName: "ButtonImportieren",
                            title: "Importieren"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Importieren")
                    .accessibilityIdentifier("Importieren")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)

                // MARK: Impressum

                Button {
                    // Impressum wird später angebunden
                } label: {
                    Text("Impressum")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.35))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Impressum")
                .accessibilityIdentifier("Impressum")
                .padding(.bottom, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}


// MARK: - Hauptschaltflächen

private struct RomanVoiceRouteButton: View {

    let imageName: String
    let title: String

    var body: some View {

        VStack(spacing: 5) {

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 72, maxHeight: 72)
                .accessibilityHidden(true)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .shadow(
                    color: .black.opacity(0.9),
                    radius: 2,
                    x: 1,
                    y: 1
                )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}


// MARK: - Sackgassen / Räume

struct RomanVoiceRoomView: View {

    let roomName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {

        ZStack {

            // Derselbe Salon wie auf dem Startplatz
            Image("Salon")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {

                // MARK: Zurück

                HStack {

                    Button {
                        dismiss()
                    } label: {

                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Zurück")
                    .accessibilityIdentifier("Zurück")

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                // MARK: Raumname an Position des RomanVoice-Logos

                RomanVoiceRoomTitle(
                    title: roomName
                )
                .padding(.top, 8)

                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}


// MARK: - Raumtitel

private struct RomanVoiceRoomTitle: View {

    let title: String

    var body: some View {

        Text(title)
            .font(
                .system(
                    size: title == "IMPORTIEREN" ? 29 : 38,
                    weight: .bold,
                    design: .serif
                )
            )
            .tracking(2.5)
            .foregroundStyle(.white)
            .shadow(
                color: .black.opacity(0.9),
                radius: 4,
                x: 1,
                y: 2
            )
            .frame(maxWidth: 300)
            .minimumScaleFactor(0.60)
            .lineLimit(1)
            .accessibilityLabel(title)
            .accessibilityIdentifier(title)
    }
}


// MARK: - Kompatibler Einstieg

struct ContentView: View {

    var body: some View {
        RomanVoiceNavigationView()
    }
}
