import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private let roomManager = RoomManager()
    private var heartChannel: HeartChannel?
    private var overlayWindow: OverlayWindow?
    private var globalShortcut: GlobalShortcut?
    private var debugMode = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugMode = CommandLine.arguments.contains("--debug")

        let shortcut = GlobalShortcut(
            onSendHeart: { [weak self] in self?.sendHeart() },
            onToggleDebug: { [weak self] in self?.toggleDebug() }
        )
        globalShortcut = shortcut

        menuBarManager = MenuBarManager(
            roomManager: roomManager,
            onSendHeart: { [weak self] in self?.sendHeart() },
            shortcutManager: shortcut,
            debugMode: debugMode
        )

        overlayWindow = OverlayWindow()

        roomManager.onStateChange = { [weak self] in
            self?.handleRoomStateChange()
        }

        NotificationCenter.default.addObserver(
            forName: .simulateHeartReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.overlayWindow?.showHearts()
            }
        }
    }

    private func sendHeart() {
        guard roomManager.state == .connected else { return }
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
        heartChannel = HeartChannel(
            roomCode: code,
            senderID: roomManager.senderID
        )
        heartChannel?.onHeartReceived = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.roomManager.log("Heart received")
                if !self.roomManager.doNotDisturb {
                    self.overlayWindow?.showHearts()
                }
            }
        }
        heartChannel?.onLog = { [weak self] message in
            DispatchQueue.main.async {
                self?.roomManager.log(message)
            }
        }
        heartChannel?.connect()
    }

    private func stopListening() {
        heartChannel?.disconnect()
        heartChannel = nil
    }

    private func toggleDebug() {
        debugMode.toggle()
        menuBarManager?.setDebugMode(debugMode)
    }
}
