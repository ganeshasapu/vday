import SwiftUI

struct PairingView: View {
    @ObservedObject var roomManager: RoomManager
    @State private var joinCode = ""

    var body: some View {
        VStack(spacing: 8) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.purple)
                    .padding(.top, 4)

                Text("Mwah")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.bottom, 4)

            // Create Room
            GroupedSection {
                MenuRow(
                    icon: "plus.circle.fill",
                    iconColor: .purple,
                    label: "Create a New Room",
                    action: { roomManager.createRoom() }
                )
            }

            // "or" divider
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 0.5)
                Text("or")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 0.5)
            }
            .padding(.horizontal, 4)

            // Join Room
            GroupedSection {
                HStack(spacing: 10) {
                    Image(systemName: "number")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                    TextField("Enter room code", text: $joinCode)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .onChange(of: joinCode) { newValue in
                            let uppercased = newValue.uppercased()
                            if uppercased != newValue { joinCode = uppercased }
                        }
                        .onSubmit {
                            guard !joinCode.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            roomManager.joinRoom(code: joinCode)
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)

                InsetDivider()

                MenuRow(
                    icon: "arrow.right.circle.fill",
                    iconColor: .blue,
                    label: "Join Room",
                    action: { roomManager.joinRoom(code: joinCode) }
                )
                .opacity(joinCode.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1.0)
                .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Error message
            if let error = roomManager.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 4)
            }
        }
    }
}
