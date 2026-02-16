import SwiftUI

struct MainView: View {
    @ObservedObject var roomManager: RoomManager
    @ObservedObject var updaterManager: UpdaterManager
    let onSendHeart: () -> Void
    @ObservedObject var shortcutManager: GlobalShortcut
    let debugMode: Bool

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if showSettings {
                    SettingsView(
                        shortcutManager: shortcutManager,
                        onBack: { showSettings = false }
                    )
                    .transition(.opacity)
                } else {
                    Group {
                        switch roomManager.state {
                        case .disconnected, .creating, .joining:
                            PairingView(roomManager: roomManager)
                        case .connected:
                            ConnectedView(
                                roomManager: roomManager,
                                onSendHeart: onSendHeart,
                                shortcutManager: shortcutManager,
                                onShowSettings: { showSettings = true }
                            )
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showSettings)
            .animation(.easeInOut(duration: 0.2), value: roomManager.state)

            if debugMode && !showSettings {
                DebugView(roomManager: roomManager, onSendHeart: onSendHeart)
            }

            GroupedSection {
                MenuRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .blue,
                    label: "Check for Updates...",
                    action: { updaterManager.checkForUpdates() }
                )
                .disabled(!updaterManager.canCheckForUpdates)

                InsetDivider()

                MenuRow(
                    icon: "xmark.circle",
                    iconColor: .secondary,
                    label: "Quit Mwah",
                    action: { NSApplication.shared.terminate(nil) }
                )
            }
        }
        .padding(12)
    }
}
