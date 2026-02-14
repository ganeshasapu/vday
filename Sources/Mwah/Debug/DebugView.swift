import SwiftUI

struct DebugView: View {
    @ObservedObject var roomManager: RoomManager
    let onSendHeart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Panel")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.orange)

            // State info
            HStack {
                Text("State:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(stateDescription)
                    .font(.caption2)
                    .fontWeight(.medium)
            }

            HStack {
                Text("Room:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(roomManager.roomCode ?? "none")
                    .font(.system(.caption2, design: .monospaced))
            }

            HStack {
                Text("ID:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(roomManager.senderID.prefix(8)) + "...")
                    .font(.system(.caption2, design: .monospaced))
            }

            Divider()

            // Actions
            HStack(spacing: 8) {
                Button("Send Heart") {
                    onSendHeart()
                }
                .font(.caption)
                .controlSize(.small)

                Button("Simulate Receive") {
                    roomManager.log("Simulated heart received")
                    NotificationCenter.default.post(name: .simulateHeartReceived, object: nil)
                }
                .font(.caption)
                .controlSize(.small)
            }

            Divider()

            // Event log
            Text("Event Log")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(roomManager.eventLog.enumerated()), id: \.offset) { index, entry in
                            Text(entry)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .id(index)
                        }
                    }
                }
                .frame(height: 120)
                .onChange(of: roomManager.eventLog.count) { _ in
                    if let last = roomManager.eventLog.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.05))
    }

    private var stateDescription: String {
        switch roomManager.state {
        case .disconnected: return "Disconnected"
        case .creating: return "Creating..."
        case .joining: return "Joining..."
        case .connected: return "Connected"
        }
    }
}

extension Notification.Name {
    static let simulateHeartReceived = Notification.Name("simulateHeartReceived")
}
