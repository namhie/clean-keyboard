import Carbon.HIToolbox
import Foundation
import IOKit
import IOKit.hidsystem

/// Caps Lock переключается на уровне HID и может сработать, даже если событие съедено тапом.
/// Поэтому запоминаем состояние до блокировки и возвращаем его после.
enum CapsLockGuard {
    static func read() -> Bool? {
        withConnection { connect in
            var state = false
            let result = IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &state)
            return result == KERN_SUCCESS ? state : nil
        }
    }

    static func restore(_ value: Bool) {
        guard read() != value else { return }
        _ = withConnection { connect in
            IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), value)
        }
    }

    private static func withConnection<T>(_ body: (io_connect_t) -> T?) -> T? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var connect: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else {
            return nil
        }
        defer { IOServiceClose(connect) }
        return body(connect)
    }
}

/// Caps Lock в русской настройке macOS переключает раскладку — возвращаем исходную.
enum InputSourceGuard {
    static func current() -> TISInputSource? {
        TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    }

    static func restore(_ source: TISInputSource) {
        guard let now = current(), id(of: now) != id(of: source) else { return }
        TISSelectInputSource(source)
    }

    private static func id(of source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}

/// Не даёт экрану погаснуть, пока идёт протирка.
final class SleepGuard {
    private var activity: NSObjectProtocol?

    func begin() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled, .userInitiated],
            reason: "Протирка клавиатуры"
        )
    }

    func end() {
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }
}

/// Secure Input (в фокусе поле пароля) отключает все event tap'ы в системе.
enum SecureInput {
    static var isEnabled: Bool { IsSecureEventInputEnabled() }
}
