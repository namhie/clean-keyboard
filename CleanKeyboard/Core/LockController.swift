import AppKit
import Carbon.HIToolbox
import Observation

/// Управляет сеансом протирки: отсчёт → блокировка → финал.
@Observable
final class LockController {
    static let shared = LockController()

    enum Phase: Equatable {
        case idle
        case countdown(Int)
        case locked
        case finished
    }

    /// Даже «без таймера» блокировка снимется сама через 10 минут — на всякий случай.
    static let hardLimit: TimeInterval = 10 * 60
    static let countdownSeconds = 3
    static let extraTime: TimeInterval = 30

    private(set) var phase: Phase = .idle {
        didSet {
            // Страховка: без сеанса оверлея на экране быть не должно.
            if phase == .idle, overlay.isShowing { overlay.hide() }
        }
    }
    private(set) var mode: LockMode = .keyboard
    private(set) var startedAt = Date()
    private(set) var deadline: Date?
    private(set) var cleanedKeys: Set<UInt16> = []
    /// Счётчик нажатий по клавише — триггер анимации вспышки.
    private(set) var pulses: [UInt16: Int] = [:]
    private(set) var pressCount = 0
    private(set) var secureInputActive = false
    /// Длительность завершённого сеанса — для экрана «Чисто!».
    private(set) var sessionLength: TimeInterval = 0

    let keyboardKind = KeyLayout.currentKind
    let countableCodes: Set<UInt16>

    @ObservationIgnored private let blocker = EventBlocker { code in
        DispatchQueue.main.async {
            MainActor.assumeIsolated { LockController.shared.registerPress(code) }
        }
    }
    @ObservationIgnored private let overlay = OverlayWindowController()
    @ObservationIgnored private let sleepGuard = SleepGuard()
    @ObservationIgnored private var savedCapsLock: Bool?
    @ObservationIgnored private var savedInputSource: TISInputSource?
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private var duration: LockDuration = .minute1

    private init() {
        countableCodes = KeyLayout.countableCodes(for: keyboardKind)
        observeSystemEvents()
    }

    var isActive: Bool { phase != .idle }
    var isLocked: Bool { phase == .locked }

    var cleanedCount: Int { cleanedKeys.intersection(countableCodes).count }
    var totalKeys: Int { countableCodes.count }

    /// Время до автоснятия (по таймеру или по жёсткому пределу).
    func remaining(at date: Date) -> TimeInterval {
        max(0, effectiveDeadline.timeIntervalSince(date))
    }

    /// Длина текущего «окна» таймера для кольца прогресса.
    var timerSpan: TimeInterval { effectiveDeadline.timeIntervalSince(startedAt) }

    var hasTimer: Bool { deadline != nil }

    private var effectiveDeadline: Date {
        min(deadline ?? .distantFuture, startedAt.addingTimeInterval(Self.hardLimit))
    }

    // MARK: - Управление

    /// Старт с панели или по горячей клавише. Повторное нажатие во время отсчёта отменяет его.
    func toggle(mode: LockMode? = nil) {
        switch phase {
        case .idle: start(mode: mode)
        case .countdown: cancel()
        case .locked, .finished: break
        }
    }

    func start(mode: LockMode? = nil) {
        guard phase == .idle, !NSScreen.screens.isEmpty else { return }

        Permissions.shared.refresh()
        guard Permissions.shared.isTrusted else {
            WindowPresenter.showOnboarding()
            return
        }

        self.mode = mode ?? AppSettings.mode
        duration = AppSettings.duration
        cleanedKeys = []
        pulses = [:]
        pressCount = 0
        startedAt = .now
        deadline = nil
        savedCapsLock = CapsLockGuard.read()
        savedInputSource = InputSourceGuard.current()

        // Активируем себя: поле пароля в другом приложении теряет фокус и Secure Input обычно снимается.
        NSApp.activate()
        overlay.show(controller: self)

        sessionTask?.cancel()
        if AppSettings.countdownEnabled {
            // Фаза меняется сразу, а не в задаче: иначе второй start() успел бы пройти guard
            // и оставить «осиротевшую» задачу, которая заблокирует ввод без оверлея.
            phase = .countdown(Self.countdownSeconds)
            sessionTask = Task { [weak self] in
                for n in stride(from: Self.countdownSeconds, through: 1, by: -1) {
                    self?.phase = .countdown(n)
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { return }
                }
                self?.engage()
            }
        } else {
            engage()
        }
    }

    func cancel() {
        guard case .countdown = phase else { return }
        sessionTask?.cancel()
        sessionTask = nil
        phase = .idle
        overlay.hide()
    }

    func addTime() {
        guard isLocked else { return }
        let base = max(deadline ?? .now, .now)
        deadline = base.addingTimeInterval(Self.extraTime)
    }

    /// Обычное завершение — с анимацией «готово».
    func unlock() {
        guard isLocked else { return }
        sessionLength = Date.now.timeIntervalSince(startedAt)
        release()
        phase = .finished
        playSound("Glass")
        sessionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            // Сначала фаза, потом скрытие: скрытие само шлёт уведомления об экранах.
            self?.phase = .idle
            self?.overlay.hide()
        }
    }

    /// Мгновенное снятие без анимации (сон, блокировка экрана).
    func emergencyUnlock() {
        guard isActive else { return }
        sessionTask?.cancel()
        sessionTask = nil
        if isLocked { release() }
        phase = .idle
        overlay.hide(animated: false)
    }

    private func screensChanged() {
        // Только во время отсчёта или блокировки, только при реальной смене мониторов
        // и только если оверлей ещё на экране — иначе можно «воскресить» его после снятия.
        switch phase {
        case .countdown, .locked: break
        case .idle, .finished: return
        }
        guard overlay.isShowing, overlay.screensChanged else { return }
        guard !NSScreen.screens.isEmpty else {
            emergencyUnlock()
            return
        }
        blocker.passRect = .null
        overlay.show(controller: self)
    }

    func updateUnlockRect(_ rect: CGRect) {
        blocker.passRect = rect
    }

    #if DEBUG
    /// Показывает оверлей без перехвата ввода — для проверки вёрстки.
    /// Запуск: `"Clean Keyboard.app/Contents/MacOS/Clean Keyboard" -PreviewOverlay full`
    /// (keyboard | full | countdown | finished). Закрывается сам через 8 секунд.
    func showPreview(_ name: String) {
        mode = name == "full" ? .full : .keyboard
        startedAt = .now.addingTimeInterval(-17)
        deadline = .now.addingTimeInterval(43)
        cleanedKeys = Set(countableCodes.shuffled().prefix(31))
        sessionLength = 72
        phase = switch name {
        case "countdown": .countdown(3)
        case "finished": .finished
        default: .locked
        }
        overlay.show(controller: self)
        // Тот же путь завершения, что у настоящего unlock(): finished → idle → скрытие.
        Task {
            try? await Task.sleep(for: .seconds(6))
            if phase == .locked { phase = .finished }
            try? await Task.sleep(for: .seconds(1.6))
            phase = .idle
            overlay.hide()
        }
    }
    #endif

    // MARK: - Внутреннее

    private func engage() {
        switch phase {
        case .idle, .countdown: break
        case .locked, .finished: return
        }
        // +5 с к пределу: сторожевой таймер тапа срабатывает, только если главный поток завис.
        guard blocker.start(blockPointer: mode == .full, maxDuration: Self.hardLimit + 5) else {
            // macOS не дала создать тап — значит, разрешения нет (или его отозвали).
            overlay.hide(animated: false)
            phase = .idle
            Permissions.shared.refresh()
            WindowPresenter.showOnboarding()
            return
        }
        startedAt = .now
        deadline = duration.interval.map { Date.now.addingTimeInterval($0) }
        sleepGuard.begin()
        secureInputActive = SecureInput.isEnabled
        phase = .locked
        playSound("Tink")

        sessionTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, self.isLocked else { return }
                self.secureInputActive = SecureInput.isEnabled
                self.enforceLockState()
                if self.remaining(at: .now) <= 0 {
                    self.unlock()
                    return
                }
            }
        }
    }

    private func release() {
        sessionTask?.cancel()
        sessionTask = nil
        blocker.stop()
        blocker.passRect = .null
        sleepGuard.end()
        enforceLockState()
        savedCapsLock = nil
        savedInputSource = nil
    }

    /// Caps Lock переключается на уровне драйвера ещё до тапа (особенно в сочетании с другой
    /// клавишей), а в русской настройке ещё и меняет раскладку. Возвращаем всё как было.
    private func enforceLockState() {
        if let savedCapsLock { CapsLockGuard.restore(savedCapsLock) }
        if let savedInputSource { InputSourceGuard.restore(savedInputSource) }
    }

    private func registerPress(_ rawCode: UInt16) {
        guard isLocked else { return }
        let code = KeyLayout.canonical(rawCode)
        if code == UInt16(kVK_CapsLock) { enforceLockState() }
        cleanedKeys.insert(code)
        pulses[code, default: 0] += 1
        pressCount += 1
    }

    private func playSound(_ name: String) {
        guard AppSettings.soundsEnabled else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    /// Если Mac уснул или экран заблокировали (например, задели Touch ID) — снимаем блокировку,
    /// чтобы на экране входа можно было ввести пароль.
    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { LockController.shared.emergencyUnlock() }
            }
        }
        // Подключили/отключили монитор — пересоздаём оверлей, иначе рамка кнопки «Готово»
        // устареет и в полном режиме её не получится нажать.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { LockController.shared.screensChanged() }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { LockController.shared.emergencyUnlock() }
        }
    }
}
