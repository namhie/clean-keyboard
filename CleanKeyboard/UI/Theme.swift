import SwiftUI

nonisolated enum Theme {
    static let mint = Color(red: 0.24, green: 0.92, blue: 0.80)
    static let teal = Color(red: 0.16, green: 0.74, blue: 0.86)
    static let blue = Color(red: 0.29, green: 0.47, blue: 1.00)
    static let violet = Color(red: 0.55, green: 0.36, blue: 0.98)

    static let accent = teal

    static let accentGradient = LinearGradient(
        colors: [mint, teal, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ringGradient = AngularGradient(
        colors: [mint, teal, blue, violet, mint],
        center: .center
    )

    static let titleFont = Font.system(size: 34, weight: .bold, design: .rounded)
}

extension TimeInterval {
    /// 75 → «1:15».
    var clockString: String {
        let total = Int(rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Иконка приложения (из Assets) — для шапок окон.
struct AppIconView: View {
    var size: CGFloat = 64

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .shadow(color: Theme.teal.opacity(0.35), radius: size * 0.25, y: size * 0.08)
    }
}

/// Сочетание клавиш в виде маленьких «клавиш».
struct ShortcutBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(minWidth: 20, minHeight: 20)
                    .padding(.horizontal, 2)
                    .background(.quaternary, in: .rect(cornerRadius: 5, style: .continuous))
            }
        }
    }
}
