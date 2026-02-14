import SwiftUI

struct ConnectedView: View {
    @ObservedObject var roomManager: RoomManager
    let onSendHeart: () -> Void
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Connected!")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.pink)

            if let code = roomManager.roomCode {
                VStack(spacing: 4) {
                    Text("Room Code")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text(code)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                            .textSelection(.enabled)

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(code, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy room code")
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAnimating = true
                }
                onSendHeart()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAnimating = false
                }
            }) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.pink, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
            .help("Send a heart (Cmd+Shift+H)")

            Text("Press **Cmd+Shift+H** anytime")
                .font(.caption2)
                .foregroundColor(.secondary)

            Toggle(isOn: $roomManager.doNotDisturb) {
                Label("Do Not Disturb", systemImage: "moon.fill")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Divider()

            Button(action: { roomManager.disconnect() }) {
                Text("Disconnect")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(20)
    }
}
