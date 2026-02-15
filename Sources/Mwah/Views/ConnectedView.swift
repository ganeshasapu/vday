import SwiftUI

struct ConnectedView: View {
    @ObservedObject var roomManager: RoomManager
    let onSendHeart: () -> Void
    @ObservedObject var shortcutManager: GlobalShortcut
    let onShowSettings: () -> Void
    @State private var isAnimating = false
    @State private var copied = false
    @State private var showSent = false
    @State private var isHoveredCode = false

    @State private var dotPulse = false

    var body: some View {
        VStack(spacing: 8) {
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .opacity(dotPulse ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: dotPulse)
                    .onAppear { dotPulse = true }
                Text("Connected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)

            // Hero: Send Heart
            GroupedSection {
                VStack(spacing: 10) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            isAnimating = true
                        }
                        onSendHeart()
                        withAnimation(.easeOut(duration: 0.2)) { showSent = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isAnimating = false
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeIn(duration: 0.3)) { showSent = false }
                        }
                    }) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.white)
                            .scaleEffect(isAnimating ? 1.25 : 1.0)
                            .frame(width: 64, height: 64)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.pink, .red],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .pink.opacity(0.3), radius: isAnimating ? 12 : 6, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Send a heart (\(shortcutManager.sendHeartDisplayString))")

                    if showSent {
                        Text("Sent!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.pink)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    } else {
                        Text("Press **\(shortcutManager.sendHeartDisplayString)** anytime")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }

            // Room Code
            if let code = roomManager.roomCode {
                GroupedSection {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { copied = false }
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "number")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.pink)
                                .frame(width: 26, height: 26)
                                .background(Color.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                            Text("Room Code")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(code)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundStyle(copied ? .green : .secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isHoveredCode ? Color.primary.opacity(0.06) : Color.clear)
                    )
                    .onHover { hovering in isHoveredCode = hovering }
                }
            }

            // Settings & Actions
            GroupedSection {
                MenuToggleRow(
                    icon: "moon.fill",
                    iconColor: .indigo,
                    label: "Do Not Disturb",
                    isOn: $roomManager.doNotDisturb
                )

                InsetDivider()

                MenuRow(
                    icon: "keyboard",
                    iconColor: .gray,
                    label: "Shortcuts",
                    trailingText: shortcutManager.sendHeartDisplayString,
                    action: onShowSettings
                )

                InsetDivider()

                MenuRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    iconColor: .secondary,
                    label: "Disconnect",
                    action: { roomManager.disconnect() }
                )
            }
        }
    }
}
