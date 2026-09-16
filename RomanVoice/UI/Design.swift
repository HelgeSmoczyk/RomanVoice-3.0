import SwiftUI

enum Room: String { case salon, library, reading, audio, desk, settings
    var focus: UnitPoint {
        switch self { case .salon: return .center; case .library: return UnitPoint(x: 0.26, y: 0.3); case .reading: return UnitPoint(x: 0.25, y: 0.56); case .audio: return UnitPoint(x: 0.82, y: 0.42); case .desk: return UnitPoint(x: 0.58, y: 0.72); case .settings: return .center }
    }
    var zoom: CGFloat { self == .salon ? 1 : 2.2 }
}
enum RomanStyle {
    static let green = Color(red: 0.035, green: 0.13, blue: 0.08)
    static let lightGreen = Color(red: 0.14, green: 0.29, blue: 0.19)
    static let gold = Color(red: 0.83, green: 0.61, blue: 0.29)
    static let cream = Color(red: 0.97, green: 0.94, blue: 0.85)
}
struct SceneBackdrop: View {
    var room: Room
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let base = max(size.width / 1024, size.height / 1536)
            let width = 1024 * base * room.zoom
            let height = 1536 * base * room.zoom
            let centerX = min(width / 2, max(size.width - width / 2, size.width / 2 + (0.5 - room.focus.x) * width))
            let centerY = min(height / 2, max(size.height - height / 2, size.height / 2 + (0.5 - room.focus.y) * height))
            Image("Salon").resizable().frame(width: width, height: height).position(x: centerX, y: centerY)
            if room == .settings {
                Color.black.opacity(0.56)
                Image("ReferenceSettings").resizable().scaledToFill().frame(width: size.width * 3, height: size.height * 2).offset(x: -size.width * 2, y: -size.height * 0.45).opacity(0.35)
            }
        }.clipped().ignoresSafeArea().accessibilityHidden(true)
    }
}
struct RomanPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(18).background {
            RoundedRectangle(cornerRadius: 13).fill(LinearGradient(colors: [RomanStyle.lightGreen.opacity(0.98), RomanStyle.green, .black.opacity(0.97)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(RomanStyle.gold.opacity(0.75), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
        }
    }
}
struct RomanButton: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.body, design: .serif)).padding(.horizontal, 16).padding(.vertical, 12)
            .foregroundStyle(prominent ? Color.black : RomanStyle.cream)
            .background(LinearGradient(colors: prominent ? [RomanStyle.gold, .orange] : [RomanStyle.lightGreen, RomanStyle.green], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(RomanStyle.gold.opacity(0.8), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
struct MenuRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).frame(width: 28).foregroundStyle(RomanStyle.gold)
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(.headline, design: .serif)); Text(subtitle).font(.caption).opacity(0.7) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(RomanStyle.gold)
            }.padding(.vertical, 10).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
struct PageHeader: View {
    let title: String
    let subtitle: String
    var back: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            Button(action: back) { Image(systemName: "chevron.left").frame(width: 44, height: 44).background(RomanStyle.green, in: Circle()).overlay(Circle().stroke(RomanStyle.gold)) }.accessibilityLabel("Zurück")
            Spacer()
            VStack(spacing: 5) { Text(title).font(.custom("EBGaramond-Regular", size: 33)); Text(subtitle).font(.system(.subheadline, design: .serif)) }.multilineTextAlignment(.center).shadow(radius: 5)
            Spacer(); Color.clear.frame(width: 44, height: 44)
        }.padding(.horizontal, 18).padding(.top, 6)
    }
}
