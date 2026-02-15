import SwiftUI

struct SettingsView: View {
    @ObservedObject var shortcutManager: GlobalShortcut
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Keyboard Shortcuts")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)

            GroupedSection {
                ShortcutRecorderRow(
                    icon: "heart.fill",
                    iconColor: .pink,
                    label: "Send Heart",
                    currentCombo: shortcutManager.sendHeartCombo,
                    onChange: { shortcutManager.updateSendHeartCombo($0) }
                )

                InsetDivider()

                ShortcutRecorderRow(
                    icon: "ladybug",
                    iconColor: .orange,
                    label: "Debug Panel",
                    currentCombo: shortcutManager.debugCombo,
                    onChange: { shortcutManager.updateDebugCombo($0) }
                )
            }

            GroupedSection {
                MenuRow(
                    icon: "chevron.left",
                    iconColor: .secondary,
                    label: "Back",
                    action: onBack
                )
            }
        }
    }
}
