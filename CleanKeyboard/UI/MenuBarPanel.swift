import SwiftUI

struct MenuBarLabel: View {
    let controller = LockController.shared

    var body: some View {
        Image(systemName: controller.isLocked ? "lock.fill" : "keyboard")
    }
}

/// Панель, открывающаяся по клику на значок в строке меню.
struct MenuBarPanel: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.duration) private var duration = LockDuration.minute1.rawValue
    @AppStorage(SettingsKey.mode) private var defaultMode = LockMode.keyboard.rawValue
    @AppStorage(SettingsKey.hotKeyCode) private var hotKeyCode = Int(HotKeyShortcut.default.keyCode)
    @AppStorage(SettingsKey.hotKeyModifiers) private var hotKeyModifiers = Int(HotKeyShortcut.default.modifiers)

    private let permissions = Permissions.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if !permissions.isTrusted {
                permissionBanner
            }

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(LockMode.allCases) { mode in
                        ModeTile(mode: mode, isDefault: mode.rawValue == defaultMode) {
                            dismiss()
                            LockController.shared.start(mode: mode)
                        }
                    }
                }
            }
            .disabled(!permissions.isTrusted)
            .opacity(permissions.isTrusted ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 8) {
                Text("Автоснятие")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker("Автоснятие", selection: $duration) {
                    ForEach(LockDuration.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider().opacity(0.6)

            HStack {
                Label("Быстрый старт", systemImage: "bolt.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                ShortcutBadge(text: shortcut.displayString)
            }

            HStack {
                Button("Выйти") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .font(.callout)
        }
        .padding(18)
        .frame(width: 340)
        .onAppear { permissions.refresh() }
    }

    private var shortcut: HotKeyShortcut {
        HotKeyShortcut(keyCode: UInt32(truncatingIfNeeded: hotKeyCode), modifiers: UInt32(truncatingIfNeeded: hotKeyModifiers))
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppIconView(size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Clean Keyboard")
                    .font(.headline)
                Text("Выбери режим и протирай")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
                WindowPresenter.showSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Настройки")
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Нужен «Универсальный доступ»")
                    .font(.callout.weight(.semibold))
                Text("Без него macOS не даст блокировать клавиши")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Выдать") {
                dismiss()
                WindowPresenter.showOnboarding()
            }
            .buttonStyle(.glassProminent)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding(12)
        .glassEffect(.regular.tint(.orange.opacity(0.12)), in: .rect(cornerRadius: 14))
    }
}

struct ModeTile: View {
    let mode: LockMode
    let isDefault: Bool
    /// Крупная плитка для главного окна.
    var large = false
    let action: () -> Void

    @State private var isHovered = false

    private var radius: CGFloat { large ? 26 : 18 }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: large ? 18 : 12) {
                HStack(alignment: .top) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: large ? 44 : 26, weight: .semibold))
                        .foregroundStyle(Theme.accentGradient)
                        .symbolEffect(.bounce, value: isHovered)
                        .frame(height: large ? 52 : 30)
                    Spacer()
                    if isDefault {
                        Image(systemName: "bolt.fill")
                            .font(large ? .callout : .caption2)
                            .foregroundStyle(.secondary)
                            .help("Запускается быстрым сочетанием")
                    }
                }
                VStack(alignment: .leading, spacing: large ? 4 : 2) {
                    Text(mode.title)
                        .font(large ? .title2.weight(.bold) : .headline)
                    Text(large ? mode.details : mode.subtitle)
                        .font(large ? .callout : .caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if large {
                    Spacer(minLength: 0)
                    Label("Начать", systemImage: "play.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isHovered ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(.secondary))
                }
            }
            .frame(maxWidth: .infinity, minHeight: large ? 180 : nil, alignment: .topLeading)
            .padding(large ? 22 : 14)
            .contentShape(.rect(cornerRadius: radius))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: radius))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.2), value: isHovered)
    }
}
