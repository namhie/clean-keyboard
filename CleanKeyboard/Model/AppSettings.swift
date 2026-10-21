import Foundation

enum LockMode: String, CaseIterable, Identifiable {
    /// Блокируется только клавиатура, трекпад работает.
    case keyboard
    /// Блокируются клавиатура и трекпад, снять можно удержанием «Готово» или по таймеру.
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboard: "Клавиатура"
        case .full: "Полная"
        }
    }

    var subtitle: String {
        switch self {
        case .keyboard: "Трекпад работает"
        case .full: "Клавиши и трекпад"
        }
    }

    var details: String {
        switch self {
        case .keyboard: "Клавиши заблокированы, трекпад работает — им и нажмёшь «Готово»"
        case .full: "Блокируются клавиши и трекпад. Снять — удержанием кнопки или по таймеру"
        }
    }

    var symbol: String {
        switch self {
        case .keyboard: "keyboard"
        case .full: "laptopcomputer"
        }
    }

    var lockedTitle: String {
        switch self {
        case .keyboard: "Клавиатура заблокирована"
        case .full: "Клавиатура и трекпад заблокированы"
        }
    }
}

enum LockDuration: Int, CaseIterable, Identifiable {
    case seconds30 = 30
    case minute1 = 60
    case minutes2 = 120
    case minutes5 = 300
    case unlimited = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .seconds30: "30 с"
        case .minute1: "1 мин"
        case .minutes2: "2 мин"
        case .minutes5: "5 мин"
        case .unlimited: "∞"
        }
    }

    /// Секунды до автоснятия; `nil`, если без таймера.
    var interval: TimeInterval? { rawValue == 0 ? nil : TimeInterval(rawValue) }
}

/// Ключи UserDefaults. Значения читаются через `@AppStorage` во вьюхах и через `AppSettings` в логике.
enum SettingsKey {
    static let mode = "lockMode"
    static let duration = "lockDuration"
    static let countdown = "countdownEnabled"
    static let sounds = "soundsEnabled"
    static let hotKeyCode = "hotKeyCode"
    static let hotKeyModifiers = "hotKeyModifiers"
}

enum AppSettings {
    private static var defaults: UserDefaults { .standard }

    static func registerDefaults() {
        defaults.register(defaults: [
            SettingsKey.mode: LockMode.keyboard.rawValue,
            SettingsKey.duration: LockDuration.minute1.rawValue,
            SettingsKey.countdown: true,
            SettingsKey.sounds: true,
            SettingsKey.hotKeyCode: Int(HotKeyShortcut.default.keyCode),
            SettingsKey.hotKeyModifiers: Int(HotKeyShortcut.default.modifiers),
        ])
    }

    static var mode: LockMode {
        LockMode(rawValue: defaults.string(forKey: SettingsKey.mode) ?? "") ?? .keyboard
    }

    static var duration: LockDuration {
        LockDuration(rawValue: defaults.integer(forKey: SettingsKey.duration)) ?? .minute1
    }

    static var countdownEnabled: Bool { defaults.bool(forKey: SettingsKey.countdown) }
    static var soundsEnabled: Bool { defaults.bool(forKey: SettingsKey.sounds) }

    static var hotKey: HotKeyShortcut {
        get {
            HotKeyShortcut(
                keyCode: UInt32(truncatingIfNeeded: defaults.integer(forKey: SettingsKey.hotKeyCode)),
                modifiers: UInt32(truncatingIfNeeded: defaults.integer(forKey: SettingsKey.hotKeyModifiers))
            )
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: SettingsKey.hotKeyCode)
            defaults.set(Int(newValue.modifiers), forKey: SettingsKey.hotKeyModifiers)
        }
    }
}
