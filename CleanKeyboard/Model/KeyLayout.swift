import Carbon.HIToolbox
import Foundation

/// Одна клавиша на схеме клавиатуры MacBook.
struct KeySpec: Identifiable {
    enum Style { case normal, function, touchID }

    let id: String
    /// Виртуальный keyCode (kVK_*). `nil` — клавиша, которую заблокировать нельзя (Touch ID).
    let code: UInt16?
    let label: String
    /// Вторая подпись (русская буква на клавише).
    let secondary: String?
    /// Ширина в «юнитах» (1 = обычная буквенная клавиша).
    let width: CGFloat
    let style: Style

    init(_ label: String, _ code: UInt16?, width: CGFloat = 1, secondary: String? = nil, style: Style = .normal) {
        self.id = "\(label)-\(code.map(String.init) ?? "x")-\(width)"
        self.label = label
        self.code = code
        self.width = width
        self.secondary = secondary
        self.style = style
    }
}

/// Схема встроенной клавиатуры MacBook (Apple Silicon) и сопоставление событий с клавишами.
enum KeyLayout {
    enum Kind { case ansi, iso }

    /// Тип встроенной клавиатуры. У MacBook, продающихся в России, обычно ISO.
    static var currentKind: Kind {
        KBGetLayoutType(Int16(LMGetKbdType())) == kKeyboardISO ? .iso : .ansi
    }

    /// Показывать ли русские буквы на клавишах.
    static var showsCyrillic: Bool {
        Locale.preferredLanguages.contains { $0.hasPrefix("ru") || $0.hasPrefix("uk") || $0.hasPrefix("be") }
    }

    static func rows(for kind: Kind, cyrillic: Bool) -> [[KeySpec]] {
        func letter(_ latin: String, _ code: Int, _ ru: String) -> KeySpec {
            KeySpec(latin, UInt16(code), secondary: cyrillic ? ru : nil)
        }

        let functionRow: [KeySpec] = [
            KeySpec("esc", UInt16(kVK_Escape), width: 1.5, style: .function),
            KeySpec("F1", UInt16(kVK_F1), style: .function),
            KeySpec("F2", UInt16(kVK_F2), style: .function),
            KeySpec("F3", UInt16(kVK_F3), style: .function),
            KeySpec("F4", UInt16(kVK_F4), style: .function),
            KeySpec("F5", UInt16(kVK_F5), style: .function),
            KeySpec("F6", UInt16(kVK_F6), style: .function),
            KeySpec("F7", UInt16(kVK_F7), style: .function),
            KeySpec("F8", UInt16(kVK_F8), style: .function),
            KeySpec("F9", UInt16(kVK_F9), style: .function),
            KeySpec("F10", UInt16(kVK_F10), style: .function),
            KeySpec("F11", UInt16(kVK_F11), style: .function),
            KeySpec("F12", UInt16(kVK_F12), style: .function),
            KeySpec("", nil, style: .touchID),
        ]

        let numberRow: [KeySpec] = [
            kind == .iso
                ? KeySpec("§", UInt16(kVK_ISO_Section), secondary: cyrillic ? ">" : nil)
                : KeySpec("`", UInt16(kVK_ANSI_Grave), secondary: cyrillic ? "ё" : nil),
            KeySpec("1", UInt16(kVK_ANSI_1)),
            KeySpec("2", UInt16(kVK_ANSI_2)),
            KeySpec("3", UInt16(kVK_ANSI_3)),
            KeySpec("4", UInt16(kVK_ANSI_4)),
            KeySpec("5", UInt16(kVK_ANSI_5)),
            KeySpec("6", UInt16(kVK_ANSI_6)),
            KeySpec("7", UInt16(kVK_ANSI_7)),
            KeySpec("8", UInt16(kVK_ANSI_8)),
            KeySpec("9", UInt16(kVK_ANSI_9)),
            KeySpec("0", UInt16(kVK_ANSI_0)),
            KeySpec("-", UInt16(kVK_ANSI_Minus)),
            KeySpec("=", UInt16(kVK_ANSI_Equal)),
            KeySpec("delete", UInt16(kVK_Delete), width: 1.5),
        ]

        var topRow: [KeySpec] = [
            KeySpec("tab", UInt16(kVK_Tab), width: 1.5),
            letter("Q", kVK_ANSI_Q, "Й"), letter("W", kVK_ANSI_W, "Ц"), letter("E", kVK_ANSI_E, "У"),
            letter("R", kVK_ANSI_R, "К"), letter("T", kVK_ANSI_T, "Е"), letter("Y", kVK_ANSI_Y, "Н"),
            letter("U", kVK_ANSI_U, "Г"), letter("I", kVK_ANSI_I, "Ш"), letter("O", kVK_ANSI_O, "Щ"),
            letter("P", kVK_ANSI_P, "З"), letter("[", kVK_ANSI_LeftBracket, "Х"),
            letter("]", kVK_ANSI_RightBracket, "Ъ"),
        ]

        var homeRow: [KeySpec] = [
            KeySpec("caps lock", UInt16(kVK_CapsLock), width: 1.8),
            letter("A", kVK_ANSI_A, "Ф"), letter("S", kVK_ANSI_S, "Ы"), letter("D", kVK_ANSI_D, "В"),
            letter("F", kVK_ANSI_F, "А"), letter("G", kVK_ANSI_G, "П"), letter("H", kVK_ANSI_H, "Р"),
            letter("J", kVK_ANSI_J, "О"), letter("K", kVK_ANSI_K, "Л"), letter("L", kVK_ANSI_L, "Д"),
            letter(";", kVK_ANSI_Semicolon, "Ж"), letter("'", kVK_ANSI_Quote, "Э"),
        ]

        var bottomRow: [KeySpec] = []
        let letters: [KeySpec] = [
            letter("Z", kVK_ANSI_Z, "Я"), letter("X", kVK_ANSI_X, "Ч"), letter("C", kVK_ANSI_C, "С"),
            letter("V", kVK_ANSI_V, "М"), letter("B", kVK_ANSI_B, "И"), letter("N", kVK_ANSI_N, "Т"),
            letter("M", kVK_ANSI_M, "Ь"), letter(",", kVK_ANSI_Comma, "Б"), letter(".", kVK_ANSI_Period, "Ю"),
            KeySpec("/", UInt16(kVK_ANSI_Slash)),
        ]

        switch kind {
        case .ansi:
            topRow.append(KeySpec("\\", UInt16(kVK_ANSI_Backslash)))
            homeRow.append(KeySpec("return", UInt16(kVK_Return), width: 1.7))
            bottomRow = [KeySpec("shift", UInt16(kVK_Shift), width: 2.25)] + letters
                + [KeySpec("shift", UInt16(kVK_RightShift), width: 2.25)]
        case .iso:
            // ISO-«Enter» рисуется двумя частями с одним keyCode — подсвечиваются вместе.
            topRow.append(KeySpec("return", UInt16(kVK_Return), width: 1.0))
            homeRow.append(KeySpec("\\", UInt16(kVK_ANSI_Backslash), secondary: cyrillic ? "Ё" : nil))
            homeRow.append(KeySpec("", UInt16(kVK_Return), width: 0.7))
            bottomRow = [KeySpec("shift", UInt16(kVK_Shift), width: 1.25),
                         KeySpec("`", UInt16(kVK_ANSI_Grave), secondary: cyrillic ? "]" : nil)] + letters
                + [KeySpec("shift", UInt16(kVK_RightShift), width: 2.25)]
        }

        let modifierRow: [KeySpec] = [
            KeySpec("fn", UInt16(kVK_Function)),
            KeySpec("⌃", UInt16(kVK_Control)),
            KeySpec("⌥", UInt16(kVK_Option)),
            KeySpec("⌘", UInt16(kVK_Command), width: 1.25),
            KeySpec("", UInt16(kVK_Space), width: 5),
            KeySpec("⌘", UInt16(kVK_RightCommand), width: 1.25),
            KeySpec("⌥", UInt16(kVK_RightOption)),
        ]

        return [functionRow, numberRow, topRow, homeRow, bottomRow, modifierRow]
    }

    /// Стрелки рисуются отдельно (перевёрнутая «T» в правом нижнем углу).
    static let arrows = (
        left: KeySpec("←", UInt16(kVK_LeftArrow)),
        up: KeySpec("↑", UInt16(kVK_UpArrow)),
        down: KeySpec("↓", UInt16(kVK_DownArrow)),
        right: KeySpec("→", UInt16(kVK_RightArrow))
    )

    /// Все уникальные keyCode схемы — для счётчика «протёрто N из M».
    static func countableCodes(for kind: Kind) -> Set<UInt16> {
        var codes = Set(rows(for: kind, cyrillic: false).flatMap { $0 }.compactMap(\.code))
        codes.formUnion([arrows.left, arrows.up, arrows.down, arrows.right].compactMap(\.code))
        return codes
    }

    // MARK: - Сопоставление событий

    /// Медиа-клавиши приходят как NSSystemDefined; блокировщик кодирует их как `mediaFlag | NX_KEYTYPE`.
    nonisolated static let mediaFlag: UInt16 = 0x1000

    /// Приводит код из блокировщика к keyCode клавиши на схеме.
    static func canonical(_ code: UInt16) -> UInt16 {
        if code & mediaFlag != 0 {
            switch code & ~mediaFlag {
            case 3: return UInt16(kVK_F1)               // яркость −
            case 2: return UInt16(kVK_F2)               // яркость +
            case 20, 18: return UInt16(kVK_F7)          // назад
            case 16: return UInt16(kVK_F8)              // play/pause
            case 19, 17: return UInt16(kVK_F9)          // вперёд
            case 7: return UInt16(kVK_F10)              // mute
            case 1: return UInt16(kVK_F11)              // громкость −
            case 0: return UInt16(kVK_F12)              // громкость +
            default: return code
            }
        }
        switch code {
        case 160: return UInt16(kVK_F3)                 // Mission Control
        case 177, 131: return UInt16(kVK_F4)            // Spotlight / Launchpad
        case 176: return UInt16(kVK_F5)                 // Диктовка
        case 178: return UInt16(kVK_F6)                 // Не беспокоить
        case UInt16(kVK_RightControl): return UInt16(kVK_Control)
        default: return code
        }
    }
}
