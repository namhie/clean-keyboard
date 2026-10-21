import SwiftUI

struct OnboardingView: View {
    private let permissions = Permissions.shared
    @State private var waiting = false
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                AppIconView(size: 96)
                Text("Clean Keyboard")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Блокирует клавиатуру, пока ты её протираешь.\nНи одной случайной буквы.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                FeatureRow(symbol: "keyboard", title: "Режим «Клавиатура»",
                           text: "Клавиши заблокированы, трекпад работает")
                FeatureRow(symbol: "laptopcomputer", title: "Режим «Полная»",
                           text: "Блокируется и трекпад — снимается удержанием кнопки")
                FeatureRow(symbol: "bolt.fill", title: "Быстрый старт",
                           text: "\(AppSettings.hotKey.displayString) из любого приложения")
            }

            permissionCard
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .frame(width: 500)
        .onAppear { permissions.startPolling() }
        .task(id: waiting) {
            guard waiting else { return }
            try? await Task.sleep(for: .seconds(8))
            withAnimation { showHelp = true }
        }
        .animation(.spring(duration: 0.45), value: permissions.isTrusted)
    }

    @ViewBuilder
    private var permissionCard: some View {
        if permissions.isTrusted {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white, .green)
                        .symbolEffect(.bounce, value: permissions.isTrusted)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Доступ получен")
                            .font(.headline)
                        Text("Можно начинать протирку")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Button {
                    WindowPresenter.close(.onboarding)
                    WindowPresenter.showMain()
                } label: {
                    Text("Начать")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.teal)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(18)
            .glassEffect(.regular.tint(.green.opacity(0.08)), in: .rect(cornerRadius: 20))
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Нужен «Универсальный доступ»")
                            .font(.headline)
                        Text("Без него macOS не позволит перехватывать нажатия. Приложение ничего не записывает и никуда не отправляет.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    if waiting {
                        ProgressView().controlSize(.small)
                        Text("Жду разрешения…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Открыть настройки") {
                        waiting = true
                        permissions.request()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.teal)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }

                if showHelp {
                    Divider().opacity(0.5)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                        Text("Включил, но ничего не меняется? Перезапусти приложение. Если не поможет — удали Clean Keyboard из списка кнопкой «−» и добавь заново.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("Перезапустить") { permissions.relaunch() }
                            .buttonStyle(.glass)
                    }
                    .transition(.opacity)
                }
            }
            .padding(18)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accentGradient)
                .frame(width: 38, height: 38)
                .glassEffect(.regular, in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.semibold))
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
