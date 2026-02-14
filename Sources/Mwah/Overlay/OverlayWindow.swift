import AppKit
import SwiftUI

@MainActor
class OverlayWindow {
    private var panel: NSPanel?
    private let animationModel = HeartAnimationModel()

    init() {
        setupPanel()
    }

    private func setupPanel() {
        guard let screen = NSScreen.main else { return }

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

        let hostingView = NSHostingView(rootView: HeartAnimationView(model: animationModel))
        hostingView.frame = screen.frame
        panel.contentView = hostingView

        panel.orderFront(nil)
        self.panel = panel
    }

    func showHearts(count: Int? = nil) {
        animationModel.addBurst(count: count)
    }
}
