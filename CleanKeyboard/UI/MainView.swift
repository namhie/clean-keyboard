import SwiftUI

/// Главное окно — открывается при запуске и по клику на значок в Dock.
struct MainView: View {
    @AppStorage(SettingsKey.duration) private var duration = LockDuration.minute1.rawValue
    @AppStorage(SettingsKey.mode) private var defaultMode = LockMode.keyboard.rawValue
    @AppStorage(SettingsKey.hotKeyCode) private var hotKeyCode = Int(HotKeyShortcut.default.keyCode)
    @AppStorage(SettingsKey.hotKeyModifiers) private var hotKeyModifiers = Int(HotKeyShortcut.default.modifiers)

    private let permissions = Permissions.shared

    var body: some View {
        VStack(spacing: 26) {
            header

            if !permissions.isTrusted {
                permissionBanner
            }

            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 16) {
                    ForEach(LockMode.allCases) { mode in
                        ModeTile(mode: mode, isDefault: mode.rawValue == defaultMode, large: true) {
                            LockController.shared.start(mode: mode)
                        }
                    }
                }
            }
            .disabled(!permissions.isTrusted)
            .opacity(permissions.isTrusted ? 1 : 0.5)

            VStack(spacing: 10) {
                Text("Автоснятие блокировки")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker("Автоснятие", selection: $duration) {
                    ForEach(LockDuration.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 340)
            }

            footer
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(width: 600)
        .onAppear { permissions.refresh() }
        .animation(.spring(duration: 0.4), value: permissions.isTrusted)
    }

    private var header: some View {
        VStack(spacing: 10) {
            AppIconView(size: 84)
            Text("Clean Keyboard")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("Выбери режим — и протирай спокойно")
                .foregroundStyle(.secondary)
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Нужен «Универсальный доступ»")
                    .font(.headline)
                Text("Без него macOS не даст блокировать клавиши")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Выдать доступ") { WindowPresenter.showOnboarding() }
                .buttonStyle(.glassProminent)
                .tint(.orange)
        }
        .padding(16)
        .glassEffect(.regular.tint(.orange.opacity(0.12)), in: .rect(cornerRadius: 18))
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Theme.accentGradient)
            Text("Быстрый старт из любого приложения")
                .foregroundStyle(.secondary)
            ShortcutBadge(text: HotKeyShortcut(keyCode: UInt32(truncatingIfNeeded: hotKeyCode), modifiers: UInt32(truncatingIfNeeded: hotKeyModifiers)).displayString)
            Spacer()
            Button {
                WindowPresenter.showSettings()
            } label: {
                Label("Настройки", systemImage: "gearshape")
            }
            .buttonStyle(.glass)
        }
        .font(.callout)
    }
}
