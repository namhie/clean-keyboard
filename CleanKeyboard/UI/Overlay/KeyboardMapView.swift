import SwiftUI

/// Схема клавиатуры MacBook: нажатая клавиша вспыхивает и остаётся подсвеченной как «протёртая».
struct KeyboardMapView: View {
    let controller: LockController

    static let unit: CGFloat = 46
    static let gap: CGFloat = 6
    /// Все ряды — 14,5 юнита (см. `KeyLayout.rows`).
    static let width: CGFloat = 14.5 * (unit + gap) - gap

    private var unit: CGFloat { Self.unit }
    private var gap: CGFloat { Self.gap }

    private var rows: [[KeySpec]] {
        KeyLayout.rows(for: controller.keyboardKind, cyrillic: KeyLayout.showsCyrillic)
    }

    var body: some View {
        let rows = rows
        VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(row) { key in
                        cap(key, height: index == 0 ? unit * 0.62 : unit)
                    }
                    if index == rows.count - 1 {
                        arrowCluster
                    }
                }
            }
        }
    }

    private var arrowCluster: some View {
        let half = (unit - 2) / 2
        return HStack(alignment: .bottom, spacing: gap) {
            cap(KeyLayout.arrows.left, height: half)
            VStack(spacing: 2) {
                cap(KeyLayout.arrows.up, height: half)
                cap(KeyLayout.arrows.down, height: half)
            }
            cap(KeyLayout.arrows.right, height: half)
        }
    }

    private func cap(_ key: KeySpec, height: CGFloat) -> some View {
        KeyCapView(
            key: key,
            // Ширина в юнитах с учётом зазоров — так все ряды получаются одинаковой длины.
            width: key.width * (unit + gap) - gap,
            height: height,
            isCleaned: key.code.map(controller.cleanedKeys.contains) ?? false,
            pulse: key.code.flatMap { controller.pulses[$0] } ?? 0
        )
    }
}

private struct KeyCapView: View {
    let key: KeySpec
    let width: CGFloat
    let height: CGFloat
    let isCleaned: Bool
    let pulse: Int

    private struct PulseValue {
        var scale: CGFloat = 1
        var glow: Double = 0
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: min(7, height * 0.24), style: .continuous)

        label
            .frame(width: width, height: height)
            .background {
                shape.fill(isCleaned ? AnyShapeStyle(Theme.accentGradient.opacity(0.5)) : AnyShapeStyle(.white.opacity(0.06)))
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(isCleaned ? 0.6 : 0.18), .white.opacity(isCleaned ? 0.25 : 0.05)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .animation(.easeOut(duration: 0.4), value: isCleaned)
            .keyframeAnimator(initialValue: PulseValue(), trigger: pulse) { content, value in
                content
                    .scaleEffect(value.scale)
                    .brightness(value.glow * 0.35)
                    .shadow(color: Theme.mint.opacity(value.glow * 0.9), radius: 14 * value.glow)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(0.84, duration: 0.07)
                    SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
                }
                KeyframeTrack(\.glow) {
                    LinearKeyframe(1, duration: 0.05)
                    CubicKeyframe(0, duration: 0.7)
                }
            }
    }

    @ViewBuilder
    private var label: some View {
        switch key.style {
        case .touchID:
            Image(systemName: "touchid")
                .font(.system(size: height * 0.55, weight: .regular))
                .foregroundStyle(.orange.opacity(0.85))
                .help("Touch ID заблокировать нельзя")
        case .function:
            Text(key.label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(textStyle)
        case .normal:
            if key.label.count > 1 {
                // «shift», «delete»… — мелко, прижато к краю, как на настоящей клавиатуре.
                Text(key.label)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textStyle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            } else if let secondary = key.secondary {
                ZStack {
                    Text(key.label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    Text(secondary)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .opacity(0.6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                .foregroundStyle(textStyle)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            } else {
                Text(key.label)
                    .font(.system(size: key.label.count == 1 && height < 30 ? 10 : 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(textStyle)
            }
        }
    }

    private var alignment: Alignment {
        switch key.label {
        case "delete", "return": .bottomTrailing
        default: .bottomLeading
        }
    }

    private var textStyle: some ShapeStyle {
        isCleaned ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.62))
    }
}
