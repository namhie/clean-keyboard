import SwiftUI

/// Полноэкранный оверлей. На основном экране — карточка с картой клавиш, на остальных — только фон.
struct LockOverlayView: View {
    let controller: LockController
    let isPrimary: Bool
    /// Рамка кнопки «Готово» в координатах окна — контроллер окна переводит её в глобальные.
    let onUnlockFrame: (CGRect) -> Void

    var body: some View {
        ZStack {
            OverlayBackdrop()

            if isPrimary {
                content
            } else if controller.isLocked {
                Label("Идёт протирка", systemImage: "lock.fill")
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 26)
                    .padding(.vertical, 14)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .animation(.spring(duration: 0.55, bounce: 0.2), value: controller.phase)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.phase {
        case .countdown(let seconds):
            CountdownView(seconds: seconds, mode: controller.mode, onCancel: controller.cancel)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        case .locked:
            LockedView(controller: controller, onUnlockFrame: onUnlockFrame)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
        case .finished:
            FinishedView(controller: controller)
                .transition(.scale(scale: 1.06).combined(with: .opacity))
        case .idle:
            Color.clear
        }
    }
}

// MARK: - Фон

/// Затемнение и медленно «дышащий» градиент поверх размытого рабочего стола.
private struct OverlayBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
            TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion)) { context in
                let t = Float(context.date.timeIntervalSinceReferenceDate)
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0, 0], [0.5 + 0.08 * sin(t * 0.31), 0], [1, 0],
                        [0, 0.5 + 0.1 * cos(t * 0.27)],
                        [0.5 + 0.12 * sin(t * 0.23), 0.5 + 0.1 * cos(t * 0.19)],
                        [1, 0.5 + 0.1 * sin(t * 0.29)],
                        [0, 1], [0.5 + 0.08 * cos(t * 0.21), 1], [1, 1],
                    ],
                    colors: [
                        Theme.blue.opacity(0.55), .black.opacity(0.2), Theme.violet.opacity(0.45),
                        .black.opacity(0.1), Theme.teal.opacity(0.35), .black.opacity(0.15),
                        Theme.mint.opacity(0.35), .black.opacity(0.2), Theme.blue.opacity(0.5),
                    ]
                )
                .opacity(0.7)
            }
        }
    }
}

// MARK: - Отсчёт

private struct CountdownView: View {
    let seconds: Int
    let mode: LockMode
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Text("\(seconds)")
                .font(.system(size: 120, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(countsDown: true))
                .foregroundStyle(Theme.accentGradient)
                .frame(width: 220, height: 220)
                .glassEffect(.regular.tint(Theme.teal.opacity(0.18)), in: .circle)

            VStack(spacing: 8) {
                Text("Убери руки с клавиатуры")
                    .font(Theme.titleFont)
                Text(mode == .full ? "Сейчас заблокируются клавиатура и трекпад" : "Сейчас клавиатура заблокируется")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Button("Отмена", action: onCancel)
                .buttonStyle(.glass)
                .controlSize(.extraLarge)
                .keyboardShortcut(.cancelAction)
        }
        .animation(.spring(duration: 0.4), value: seconds)
    }
}

// MARK: - Блокировка

private struct LockedView: View {
    let controller: LockController
    let onUnlockFrame: (CGRect) -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 30) {
            header

            VStack(spacing: 20) {
                KeyboardMapView(controller: controller)
                CleanProgressBar(cleaned: controller.cleanedCount, total: controller.totalKeys)
                    .frame(width: KeyboardMapView.width)
            }
            .padding(26)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))

            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 16) {
                    TimerPill(controller: controller)
                        .glassEffect(.regular, in: .capsule)

                    UnlockButton(requiresHold: controller.mode == .full, action: controller.unlock)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                            onUnlockFrame(frame)
                        }
                }
            }

            hints
        }
        .onAppear { appeared = true }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: controller.mode == .full ? "lock.laptopcomputer" : "keyboard.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.accentGradient)
                .symbolEffect(.breathe, isActive: appeared)
                .frame(width: 78, height: 78)
                .glassEffect(.regular.tint(Theme.teal.opacity(0.2)), in: .circle)

            Text(controller.mode.lockedTitle)
                .font(Theme.titleFont)
            Text("Протирай спокойно — ни одно нажатие не пройдёт")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var hints: some View {
        VStack(spacing: 10) {
            if controller.secureInputActive {
                Label(
                    "Активно поле пароля — macOS может пропустить часть нажатий. Сними блокировку, закрой поле и начни заново.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .glassEffect(.regular.tint(.yellow.opacity(0.15)), in: .capsule)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 22) {
                Label("Touch ID не блокируется — нажатие заблокирует Mac", systemImage: "touchid")
                if controller.mode == .full {
                    Label("Зажми «Готово» на \(UnlockButton.holdDuration.formatted()) с", systemImage: "hand.tap")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .animation(.spring, value: controller.secureInputActive)
    }
}

// MARK: - Финал

private struct FinishedView: View {
    let controller: LockController

    @State private var bounce = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96, weight: .semibold))
                .foregroundStyle(.white, Theme.accentGradient)
                .symbolEffect(.bounce, value: bounce)

            Text("Чисто!")
                .font(.system(size: 42, weight: .bold, design: .rounded))

            Text("Протёрто \(controller.cleanedCount) из \(controller.totalKeys) клавиш · \(controller.sessionLength.clockString)")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 44)
        .glassEffect(.regular, in: .rect(cornerRadius: 40))
        .onAppear { bounce.toggle() }
    }
}
