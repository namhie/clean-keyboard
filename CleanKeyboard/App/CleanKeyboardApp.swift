import SwiftUI

@main
struct CleanKeyboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Восстанавливать окна нечего; заодно macOS не спросит «открыть окна заново?» после сбоя.
        UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true])
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.registerDefaults()
        _ = LockController.shared

        HotKey.shared.onPress = { LockController.shared.toggle() }
        HotKey.shared.register(AppSettings.hotKey)

        #if DEBUG
        if let preview = UserDefaults.standard.string(forKey: "PreviewOverlay") {
            if preview == "main" {
                Permissions.shared.forceTrustedForPreview = true
                Permissions.shared.refresh()
                WindowPresenter.showMain()
            } else if preview == "settings" {
                WindowPresenter.showSettings()
            } else if preview == "onboarding" {
                WindowPresenter.showOnboarding()
            } else {
                LockController.shared.showPreview(preview)
            }
            return
        }
        #endif

        if Permissions.shared.isTrusted {
            WindowPresenter.showMain()
        } else {
            WindowPresenter.showOnboarding()
        }
    }

    /// Клик по значку в Dock — снова показать главное окно.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { WindowPresenter.showMain() }
        return true
    }

    /// Закрытие окна не завершает приложение: горячая клавиша и значок в строке меню продолжают работать.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        LockController.shared.emergencyUnlock()
    }
}
