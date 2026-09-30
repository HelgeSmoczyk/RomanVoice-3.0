import SwiftUI

struct ConstructionView: View {
    let title: String
    let subtitle: String
    let back: () -> Void

    init(
        title: String = "Hier wird gebaut",
        subtitle: String = "Dieser Bereich ist noch nicht fertig.",
        back: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.back = back
    }

    var body: some View {
        VStack(spacing: 0) {

            PageHeader(
                title: title,
                subtitle: "RomanVoice 3.0"
            ) {
                back()
            }

            Spacer()

            VStack(spacing: 22) {

                Image(systemName: "hammer.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.orange)

                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                VStack(spacing: 7) {
                    constructionLine
                    constructionLine
                    constructionLine
                }
                .padding(.vertical, 14)

                Text("Dieser Bereich ist absichtlich noch nicht freigeschaltet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)

            Spacer()
        }
    }

    private var constructionLine: some View {
        Text("WIRD GEBAUT  ·  UNDER CONSTRUCTION  ·  WIRD GEBAUT")
            .font(.caption2.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        .orange,
                        .orange.opacity(0.55),
                        .orange,
                        .orange.opacity(0.55),
                        .orange
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.black)
            .rotationEffect(.degrees(-2))
    }
}
