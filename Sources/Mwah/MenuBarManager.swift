import AppKit
import SwiftUI

@MainActor
class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let roomManager: RoomManager
    private let onSendHeart: () -> Void
    private var debugMode: Bool

    init(roomManager: RoomManager, onSendHeart: @escaping () -> Void, debugMode: Bool) {
        self.roomManager = roomManager
        self.onSendHeart = onSendHeart
        self.debugMode = debugMode
        super.init()
        setupStatusItem()
        setupPopover()
    }

    func setDebugMode(_ enabled: Bool) {
        debugMode = enabled
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "heart.fill", accessibilityDescription: "Mwah")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: debugMode ? 500 : 300)
        popover.behavior = .transient
        popover.animates = true

        let mainView = MainView(
            roomManager: roomManager,
            onSendHeart: onSendHeart,
            debugMode: debugMode
        )
        popover.contentViewController = NSHostingController(rootView: mainView)
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            setupPopover()
            self.popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
