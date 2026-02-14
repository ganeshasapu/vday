import SwiftUI

struct MainView: View {
    @ObservedObject var roomManager: RoomManager
    let onSendHeart: () -> Void
    let debugMode: Bool

    var body: some View {
        VStack(spacing: 0) {
            switch roomManager.state {
            case .disconnected, .creating, .joining:
                PairingView(roomManager: roomManager)
            case .connected:
                ConnectedView(roomManager: roomManager, onSendHeart: onSendHeart)
            }

            if debugMode {
                Divider()
                DebugView(roomManager: roomManager, onSendHeart: onSendHeart)
            }

            Divider()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit Mwah")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
        }
        .frame(width: 260)
    }
}
