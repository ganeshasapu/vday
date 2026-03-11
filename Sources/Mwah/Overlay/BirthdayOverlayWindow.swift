import AppKit

@MainActor
class BirthdayOverlayWindow {
    private var panel: NSPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private(set) var isShowing = false

    func show() {
        guard !isShowing else { return }
        guard let screen = NSScreen.main else { return }

        isShowing = true

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let animationView = BirthdayAnimationView(frame: screen.frame) { [weak self] in
            self?.dismiss()
        }
        panel.contentView = animationView

        panel.orderFront(nil)
        self.panel = panel

        // Monitor for Escape key to dismiss early
        // Local monitor for when this app is active
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key
                self?.dismiss()
                return nil
            }
            return event
        }
        // Global monitor for when another app is frontmost (nonactivatingPanel doesn't make us key)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
            }
        }

        animationView.startSequence()
    }

    func dismiss() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let view = panel?.contentView as? BirthdayAnimationView {
            view.stopSequence()
        }
        panel?.orderOut(nil)
        panel = nil
        isShowing = false
    }
}
