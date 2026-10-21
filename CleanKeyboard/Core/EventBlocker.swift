import AppKit
import CoreGraphics
import Synchronization

/// Перехватывает события ввода на уровне HID и «съедает» их, пока активна блокировка.
///
/// Тап живёт на отдельном потоке со своим CFRunLoop: если главный поток занят анимациями,
/// macOS не отключит тап по таймауту и нажатия не «протекут». Тап существует только вместе
/// с процессом — если приложение упадёт, ввод сразу вернётся.
nonisolated final class EventBlocker: @unchecked Sendable {
    private struct State {
        var blockPointer = false
        /// Область кнопки «Готово» в глобальных координатах CG (начало — левый верхний угол главного экрана).
        var passRect: CGRect = .null
        /// Кнопку зажали: пропускаем drag/up до отпускания.
        var holdingPass = false
    }

    private let state = Mutex(State())
    private let onKey: @Sendable (UInt16) -> Void

    // Только главный поток (start/stop).
    private var runLoop: CFRunLoop?

    /// Читается потоком тапа (повторное включение), пишется главным (start/stop) — под `tapLock`.
    private let tapLock = NSLock()
    private var tapStorage: CFMachPort?
    private var currentTap: CFMachPort? {
        get { tapLock.withLock { tapStorage } }
        set { tapLock.withLock { tapStorage = newValue } }
    }

    init(onKey: @escaping @Sendable (UInt16) -> Void) {
        self.onKey = onKey
    }

    var passRect: CGRect {
        get { state.withLock { $0.passRect } }
        set { state.withLock { $0.passRect = newValue } }
    }

    /// Запускает перехват. Возвращает `false`, если macOS не дала создать тап (нет разрешения).
    ///
    /// `maxDuration` — сторожевой таймер на потоке тапа: снимает перехват сам, даже если
    /// главный поток завис и не может вызвать `stop()`.
    func start(blockPointer: Bool, maxDuration: TimeInterval) -> Bool {
        stop()
        state.withLock {
            $0.blockPointer = blockPointer
            $0.holdingPass = false
        }

        let ready = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var created = false

        let thread = Thread { [self] in
            let mask = Self.eventMask(blockPointer: blockPointer)
            guard let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: eventTapCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else {
                ready.signal()
                return
            }
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            let loop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(loop, source, .commonModes)
            let watchdog = CFRunLoopTimerCreateWithHandler(
                kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + maxDuration, 0, 0, 0
            ) { _ in
                CGEvent.tapEnable(tap: tap, enable: false)
                CFMachPortInvalidate(tap)
                CFRunLoopStop(loop)
            }
            CFRunLoopAddTimer(loop, watchdog, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            self.currentTap = tap
            self.runLoop = loop
            created = true
            ready.signal()
            CFRunLoopRun()
            CFRunLoopTimerInvalidate(watchdog)
            CFRunLoopRemoveSource(loop, source, .commonModes)
        }
        thread.name = "CleanKeyboard.EventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return created
    }

    func stop() {
        let tap = tapLock.withLock { () -> CFMachPort? in
            defer { tapStorage = nil }
            return tapStorage
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoop {
            CFRunLoopStop(runLoop)
        }
        runLoop = nil
    }

    // MARK: - Обработка

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        switch type.rawValue {
        case CGEventType.tapDisabledByTimeout.rawValue, CGEventType.tapDisabledByUserInput.rawValue:
            if let tap = currentTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass

        case CGEventType.keyDown.rawValue:
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                onKey(UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode)))
            }
            return nil

        case CGEventType.keyUp.rawValue:
            return nil

        case CGEventType.flagsChanged.rawValue:
            let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            if Self.isModifierPress(code: code, flags: event.flags) {
                onKey(code)
            }
            return nil

        case Self.systemDefinedType:
            // Медиа-клавиши (яркость, громкость, ▶︎) — subtype 8. Остальные subtype
            // относятся к кнопкам мыши, их трогаем только в «полном» режиме.
            //
            // Subtype и data1 читаем прямо из CGEvent, без NSEvent(cgEvent:): тот для Caps Lock
            // запускает обработку в системе ввода (TSM) — роняет процесс на фоновом потоке
            // и может переключить раскладку, даже если событие съедено.
            let subtype = event.getIntegerValueField(Self.subtypeField)
            let data1 = event.getIntegerValueField(Self.data1Field)
            // Кнопку питания / Touch ID не трогаем: её нажатие должно блокировать Mac как обычно
            // (subtype 1 — power key, subtype 8 с NX_POWER_KEY = 6).
            if subtype == 1 { return pass }
            if subtype == 8 {
                let keyType = UInt16(truncatingIfNeeded: (data1 & 0xFFFF_0000) >> 16)
                if keyType == 6 { return pass }
                let isDown = (data1 & 0xFF00) >> 8 == 0x0A
                if isDown { onKey(KeyLayout.mediaFlag | keyType) }
                return nil
            }
            return blocksPointer ? nil : pass

        case CGEventType.leftMouseDown.rawValue:
            let inside = state.withLock { state -> Bool in
                let hit = state.passRect.insetBy(dx: -6, dy: -6).contains(event.location)
                state.holdingPass = hit
                return hit
            }
            return inside ? pass : nil

        case CGEventType.leftMouseDragged.rawValue:
            return state.withLock { $0.holdingPass } ? pass : nil

        case CGEventType.leftMouseUp.rawValue:
            let wasHolding = state.withLock { state -> Bool in
                defer { state.holdingPass = false }
                return state.holdingPass
            }
            return wasHolding ? pass : nil

        default:
            // Правый/средний клик, скролл, жесты — в маске только в «полном» режиме.
            return nil
        }
    }

    private var blocksPointer: Bool { state.withLock { $0.blockPointer } }

    // MARK: - Маска

    private static let systemDefinedType: UInt32 = 14
    /// Недокументированные поля CGEvent для NSSystemDefined (проверено: совпадают с NSEvent.subtype/data1).
    private static let subtypeField = CGEventField(rawValue: 99)!
    private static let data1Field = CGEventField(rawValue: 149)!
    /// Жесты трекпада: rotate, beginGesture, endGesture, gesture, magnify, swipe, smartMagnify, pressure.
    private static let gestureTypes: [UInt32] = [18, 19, 20, 29, 30, 31, 32, 34]

    private static func eventMask(blockPointer: Bool) -> CGEventMask {
        var types: [UInt32] = [
            CGEventType.keyDown.rawValue,
            CGEventType.keyUp.rawValue,
            CGEventType.flagsChanged.rawValue,
            systemDefinedType,
        ]
        if blockPointer {
            types += [
                CGEventType.leftMouseDown.rawValue, CGEventType.leftMouseUp.rawValue,
                CGEventType.leftMouseDragged.rawValue,
                CGEventType.rightMouseDown.rawValue, CGEventType.rightMouseUp.rawValue,
                CGEventType.rightMouseDragged.rawValue,
                CGEventType.otherMouseDown.rawValue, CGEventType.otherMouseUp.rawValue,
                CGEventType.otherMouseDragged.rawValue,
                CGEventType.scrollWheel.rawValue,
            ] + gestureTypes
        }
        return types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1)) }
    }

    /// flagsChanged приходит и на нажатие, и на отпускание; считаем только нажатие.
    private static func isModifierPress(code: UInt16, flags: CGEventFlags) -> Bool {
        switch Int(code) {
        case 56, 60: flags.contains(.maskShift)
        case 59, 62: flags.contains(.maskControl)
        case 58, 61: flags.contains(.maskAlternate)
        case 55, 54: flags.contains(.maskCommand)
        case 63: flags.contains(.maskSecondaryFn)
        case 57: true // Caps Lock — каждое нажатие меняет флаг
        default: false
        }
    }
}

private nonisolated func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let blocker = Unmanaged<EventBlocker>.fromOpaque(userInfo).takeUnretainedValue()
    return blocker.handle(type: type, event: event)
}
