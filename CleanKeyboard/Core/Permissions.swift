import AppKit
import ApplicationServices
import Observation

/// Разрешение «Универсальный доступ» нужно, чтобы macOS дала перехватывать нажатия.
@Observable
final class Permissions {
    static let shared = Permissions()

    private(set) var isTrusted = AXIsProcessTrusted()
    @ObservationIgnored private var timer: Timer?

    private init() {
        // Вернулся из Системных настроек — сразу перепроверяем.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { Permissions.shared.refresh() }
        }
    }

    /// Перезапуск приложения — иногда macOS применяет разрешение только к новому процессу.
    func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.7; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }

    #if DEBUG
    /// Для предпросмотра главного окна в состоянии «доступ выдан».
    @ObservationIgnored var forceTrustedForPreview = false
    #endif

    func refresh() {
        var trusted = AXIsProcessTrusted()
        #if DEBUG
        trusted = trusted || forceTrustedForPreview
        #endif
        if trusted != isTrusted { isTrusted = trusted }
    }

    /// Показывает системный запрос и открывает нужную панель Системных настроек.
    func request() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openSettings()
        startPolling()
    }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// После выдачи разрешения `AXIsProcessTrusted` меняется без перезапуска — просто опрашиваем.
    func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                Permissions.shared.refresh()
                if Permissions.shared.isTrusted { Permissions.shared.stopPolling() }
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
