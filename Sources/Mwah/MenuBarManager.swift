import AppKit
import SwiftUI

@MainActor
class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let roomManager: RoomManager
    private let updaterManager: UpdaterManager
    private let onSendHeart: () -> Void
    private let shortcutManager: GlobalShortcut
    private var debugMode: Bool

    init(roomManager: RoomManager, updaterManager: UpdaterManager, onSendHeart: @escaping () -> Void, shortcutManager: GlobalShortcut, debugMode: Bool) {
        self.roomManager = roomManager
        self.updaterManager = updaterManager
        self.onSendHeart = onSendHeart
        self.shortcutManager = shortcutManager
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
        let mainView = MainView(
            roomManager: roomManager,
            updaterManager: updaterManager,
            onSendHeart: onSendHeart,
            shortcutManager: shortcutManager,
            debugMode: debugMode
        )
        let hostingController = NSHostingController(rootView: mainView)
        hostingController.sizingOptions = .preferredContentSize

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 10)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
