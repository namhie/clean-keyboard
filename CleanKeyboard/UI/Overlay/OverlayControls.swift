import SwiftUI

/// Кольцо обратного отсчёта до автоснятия.
struct TimerPill: View {
    let controller: LockController

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let remaining = controller.remaining(at: context.date)
            let span = max(controller.timerSpan, 1)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: remaining / span)
                        .stroke(Theme.ringGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: controller.hasTimer ? "timer" : "infinity")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 1) {
                    Text(remaining.clockString)
                        .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                    Text(controller.hasTimer ? "до разблокировки" : "без таймера · предел 10 мин")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 120, alignment: .leading)

                // В полном режиме клики проходят только в «Готово», поэтому кнопку не показываем.
                if controller.hasTimer && controller.mode == .keyboard {
                    Button {
                        controller.addTime()
                    } label: {
                        Text("+30 с")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .help("Добавить 30 секунд")
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
        }
    }
}

/// «Готово»: обычный клик в режиме «Клавиатура», удержание 1,5 с в полном режиме.
struct UnlockButton: View {
    let requiresHold: Bool
    let action: () -> Void

    static let holdDuration: Double = 1.5

    @State private var progress: CGFloat = 0

    var body: some View {
        if requiresHold {
            holdButton
        } else {
            Button(action: action) {
                Label("Готово", systemImage: "checkmark")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.teal)
        }
    }

    private var holdButton: some View {
        HStack(spacing: 10) {
            Image(systemName: progress > 0 ? "lock.open.fill" : "hand.point.up.left.fill")
                .contentTransition(.symbolEffect(.replace))
            Text(progress > 0 ? "Держи…" : "Готово")
        }
        .font(.title3.weight(.semibold))
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(alignment: .leading) {
            GeometryReader { geometry in
                Capsule()
                    .fill(Theme.accentGradient)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .clipShape(.capsule)
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(.capsule)
        .onLongPressGesture(minimumDuration: Self.holdDuration, maximumDistance: 60) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            action()
        } onPressingChanged: { pressing in
            withAnimation(pressing ? .linear(duration: Self.holdDuration) : .spring(duration: 0.35)) {
                progress = pressing ? 1 : 0
            }
        }
    }
}

/// Полоска «Протёрто N из M».
struct CleanProgressBar: View {
    let cleaned: Int
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cleaned == total ? "sparkles" : "hand.wave.fill")
                .foregroundStyle(Theme.accentGradient)
                .contentTransition(.symbolEffect(.replace))
            Text(cleaned == 0 ? "Нажатые клавиши подсветятся" : "Протёрто")
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(Theme.accentGradient)
                        .frame(width: geometry.size.width * CGFloat(cleaned) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 6)
            Text("\(cleaned) из \(total)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
        }
        .font(.callout)
        .animation(.spring(duration: 0.4), value: cleaned)
    }
}
