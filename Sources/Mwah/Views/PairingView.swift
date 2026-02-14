import SwiftUI

struct PairingView: View {
    @ObservedObject var roomManager: RoomManager
    @State private var joinCode = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Mwah")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            // Create room
            Button(action: { roomManager.createRoom() }) {
                Label("Create Room", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(.pink)

            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }

            // Join room
            VStack(spacing: 8) {
                TextField("Room code", text: $joinCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.center)

                Button(action: { roomManager.joinRoom(code: joinCode) }) {
                    Label("Join Room", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let error = roomManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(20)
    }
}
