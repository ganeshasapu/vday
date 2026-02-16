import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private let roomManager = RoomManager()
    private let updaterManager = UpdaterManager()
    private var heartChannel: HeartChannel?
    private let statusStore = StatusStore()
    private var overlayWindow: OverlayWindow?
    private var globalShortcut: GlobalShortcut?
    private var heartQueue: HeartQueue?
    private var lastHeartSendTime: CFTimeInterval = 0
    private var debugMode = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugMode = CommandLine.arguments.contains("--debug")

        setupMainMenu()

        let shortcut = GlobalShortcut(
            onSendHeart: { [weak self] in self?.sendHeart() },
            onToggleDebug: { [weak self] in self?.toggleDebug() }
        )
        globalShortcut = shortcut

        menuBarManager = MenuBarManager(
            roomManager: roomManager,
            updaterManager: updaterManager,
            onSendHeart: { [weak self] in self?.sendHeart() },
            shortcutManager: shortcut,
            debugMode: debugMode
        )

        overlayWindow = OverlayWindow()

        roomManager.onStateChange = { [weak self] in
            self?.handleRoomStateChange()
        }

        // Reconnect if room was restored from a previous session
        if roomManager.state == .connected {
            handleRoomStateChange()
        }

        NotificationCenter.default.addObserver(
            forName: .simulateHeartReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if let queue = self?.heartQueue {
                    queue.enqueue()
                } else {
                    self?.overlayWindow?.showHearts()
                }
            }
        }
    }

    private func sendHeart() {
        guard roomManager.state == .connected else { return }
        let now = CACurrentMediaTime()
        guard now - lastHeartSendTime >= 0.1 else { return }
        lastHeartSendTime = now
        heartChannel?.sendHeart()
        roomManager.log("Heart sent")
    }

    private func handleRoomStateChange() {
        switch roomManager.state {
        case .connected:
            startListening()
        case .disconnected:
            stopListening()
        default:
            break
        }
    }

    private func startListening() {
        guard let code = roomManager.roomCode else { return }

        heartQueue = HeartQueue { [weak self] in
            self?.overlayWindow?.showHearts()
        }

        heartChannel = HeartChannel(
            roomCode: code,
            senderID: roomManager.senderID
        )
        heartChannel?.onHeartReceived = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.roomManager.log("Heart received")
                if !self.roomManager.doNotDisturb {
                    self.heartQueue?.enqueue()
                }
            }
        }
        heartChannel?.onPartnerStatusReceived = { [weak self] dnd in
            DispatchQueue.main.async {
                self?.roomManager.partnerDoNotDisturb = dnd
            }
        }
        heartChannel?.onLog = { [weak self] message in
            DispatchQueue.main.async {
                self?.roomManager.log(message)
            }
        }
        heartChannel?.connect()

        // Persist & broadcast current DND status on connect
        statusStore.saveDND(dnd: roomManager.doNotDisturb, roomCode: code, senderID: roomManager.senderID)
        heartChannel?.sendStatus(dnd: roomManager.doNotDisturb)

        // Fetch partner's DND status from Firebase
        statusStore.fetchPartnerDND(roomCode: code, senderID: roomManager.senderID) { [weak self] dnd in
            DispatchQueue.main.async {
                self?.roomManager.partnerDoNotDisturb = dnd
            }
        }

        // Broadcast DND changes while connected
        roomManager.onDoNotDisturbChanged = { [weak self] dnd in
            guard let self, let code = self.roomManager.roomCode else { return }
            self.statusStore.saveDND(dnd: dnd, roomCode: code, senderID: self.roomManager.senderID)
            self.heartChannel?.sendStatus(dnd: dnd)
        }
    }

    private func stopListening() {
        heartChannel?.disconnect()
        heartChannel = nil
        heartQueue?.cancelAll()
        heartQueue = nil
        roomManager.onDoNotDisturbChanged = nil
    }

    private func toggleDebug() {
        debugMode.toggle()
        menuBarManager?.setDebugMode(debugMode)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }
}
