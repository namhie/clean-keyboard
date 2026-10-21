import AppKit
import SwiftUI

/// Окно без рамки, которое может стать ключевым (иначе SwiftUI-кнопки не получат клики).
/// `nonactivatingPanel` — кнопки активны, даже если macOS не дала активировать приложение.
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Первый клик сразу нажимает кнопку, а не просто активирует окно.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Показывает оверлей на всех экранах поверх всего, включая полноэкранные приложения.
final class OverlayWindowController {
    private var windows: [NSWindow] = []

    func show(controller: LockController) {
        hide(animated: false)

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let primary = Self.contentScreen(among: screens)
        // Глобальные координаты CG отсчитываются от левого верхнего угла главного экрана.
        let globalHeight = screens[0].frame.maxY

        for screen in screens {
            let isPrimary = screen == primary
            let frame = screen.frame

            let window = OverlayPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isMovable = false
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            window.hidesOnDeactivate = false

            let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
            blur.material = .fullScreenUI
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.autoresizingMask = [.width, .height]

            let root = LockOverlayView(controller: controller, isPrimary: isPrimary) { rect in
                let global = CGRect(
                    x: frame.minX + rect.minX,
                    y: (globalHeight - frame.maxY) + rect.minY,
                    width: rect.width,
                    height: rect.height
                )
                controller.updateUnlockRect(global)
            }
            let host = FirstMouseHostingView(rootView: root)
            host.sizingOptions = []
            host.frame = blur.bounds
            host.autoresizingMask = [.width, .height]
            blur.addSubview(host)

            window.contentView = blur
            window.setFrame(frame, display: false)
            window.alphaValue = 0
            window.orderFrontRegardless()
            if isPrimary { window.makeKey() }
            windows.append(window)
        }

        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            for window in windows { window.animator().alphaValue = 1 }
        }
    }

    func hide(animated: Bool = true) {
        let closing = windows
        windows = []
        guard !closing.isEmpty else { return }
        NSApp.presentationOptions = []

        guard animated else {
            closing.forEach { $0.orderOut(nil) }
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            for window in closing { window.animator().alphaValue = 0 }
        } completionHandler: {
            MainActor.assumeIsolated { closing.forEach { $0.orderOut(nil) } }
        }
    }

    /// Карточку показываем на встроенном дисплее MacBook — на него смотрят, когда протирают клавиатуру.
    private static func contentScreen(among screens: [NSScreen]) -> NSScreen {
        let builtIn = screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return CGDisplayIsBuiltin(id) != 0
        }
        return builtIn ?? NSScreen.main ?? screens[0]
    }
}
