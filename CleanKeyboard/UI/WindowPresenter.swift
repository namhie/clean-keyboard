import AppKit
import SwiftUI

/// Обычные окна (онбординг, настройки) для приложения без иконки в Dock.
enum WindowPresenter {
    enum ID: String {
        case main
        case onboarding
        case settings
    }

    private static var windows: [ID: NSWindow] = [:]

    static func showMain() {
        show(.main, title: "Clean Keyboard") { MainView() }
    }

    static func showOnboarding() {
        show(.onboarding, title: "Добро пожаловать") { OnboardingView() }
    }

    static func showSettings() {
        show(.settings, title: "Настройки Clean Keyboard") { SettingsView() }
    }

    static func close(_ id: ID) {
        windows[id]?.close()
    }

    private static func show<Content: View>(_ id: ID, title: String, content: () -> Content) {
        NSApp.activate()
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Содержимое всегда своего идеального размера (.fixedSize) и не зависит от окна,
        // а окно подгоняется под него вручную. Автоподгонка NSHostingController
        // (.preferredContentSize) зацикливала констрейнты, и AppKit ронял приложение.
        let root = content()
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                DispatchQueue.main.async { resize(id, to: size) }
            }
        let controller = NSHostingController(rootView: root)
        controller.sizingOptions = []

        let window = NSWindow(contentViewController: controller)
        window.setContentSize(controller.view.fittingSize)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = id == .settings ? .visible : .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
    }

    /// Меняет размер окна, сохраняя положение верхнего края.
    private static func resize(_ id: ID, to size: CGSize) {
        guard let window = windows[id], size.width > 0, size.height > 0 else { return }
        let current = window.contentRect(forFrameRect: window.frame)
        guard abs(current.width - size.width) > 0.5 || abs(current.height - size.height) > 0.5 else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: current.origin, size: size))
        frame.origin.y = window.frame.maxY - frame.height
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}
