import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.mode) private var mode = LockMode.keyboard.rawValue
    @AppStorage(SettingsKey.duration) private var duration = LockDuration.minute1.rawValue
    @AppStorage(SettingsKey.countdown) private var countdown = true
    @AppStorage(SettingsKey.sounds) private var sounds = true

    private let permissions = Permissions.shared

    var body: some View {
        Form {
            Section("Блокировка") {
                Picker("Режим быстрого старта", selection: $mode) {
                    ForEach(LockMode.allCases) { option in
                        Label(option.title, systemImage: option.symbol).tag(option.rawValue)
                    }
                }
                Picker("Автоснятие", selection: $duration) {
                    ForEach(LockDuration.allCases) { option in
                        Text(option == .unlimited ? "Без таймера" : option.title).tag(option.rawValue)
                    }
                }
                Toggle("Отсчёт 3 секунды перед блокировкой", isOn: $countdown)
            }

            Section("Горячая клавиша") {
                ShortcutRecorder()
            }

            Section("Общие") {
                Toggle("Звуки", isOn: $sounds)
                LaunchAtLoginToggle()
            }

            Section("Разрешения") {
                HStack {
                    Text("Универсальный доступ")
                    Spacer()
                    if permissions.isTrusted {
                        Label("Выдан", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Выдать…") { permissions.request() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { permissions.refresh() }
    }
}

private struct ShortcutRecorder: View {
    @State private var shortcut = AppSettings.hotKey
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text("Начать протирку")
            Spacer()
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Group {
                    if isRecording {
                        Text("Нажми сочетание…")
                            .foregroundStyle(Theme.teal)
                    } else {
                        Text(shortcut.displayString)
                            .font(.body.weight(.semibold))
                    }
                }
                .frame(minWidth: 130)
            }
            .buttonStyle(.glass)

            if shortcut != .default && !isRecording {
                Button {
                    save(.default)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Вернуть \(HotKeyShortcut.default.displayString)")
            }
        }
        .onDisappear { stopRecording() }
        // Окна не уничтожаются при закрытии, поэтому onDisappear может не сработать —
        // иначе монитор продолжил бы перехватывать ⌘W/⌘Q как новое сочетание.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            if isRecording { stopRecording() }
        }
    }

    private func startRecording() {
        isRecording = true
        HotKey.shared.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stopRecording()
            } else if let recorded = HotKeyShortcut(event: event) {
                save(recorded)
                stopRecording()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        HotKey.shared.register(AppSettings.hotKey)
    }

    private func save(_ value: HotKeyShortcut) {
        AppSettings.hotKey = value
        shortcut = value
        HotKey.shared.register(value)
    }
}

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Запускать при входе", isOn: Binding(
                get: { isEnabled },
                set: { update($0) }
            ))
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func update(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
