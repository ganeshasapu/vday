import SwiftUI

struct MainView: View {
    @ObservedObject var roomManager: RoomManager
    let onSendHeart: () -> Void
    let debugMode: Bool

    var body: some View {
        VStack(spacing: 8) {
            Group {
                switch roomManager.state {
                case .disconnected, .creating, .joining:
                    PairingView(roomManager: roomManager)
                        .transition(.opacity)
                case .connected:
                    ConnectedView(roomManager: roomManager, onSendHeart: onSendHeart)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: roomManager.state)

            if debugMode {
                DebugView(roomManager: roomManager, onSendHeart: onSendHeart)
            }

            GroupedSection {
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
