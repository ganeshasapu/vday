import SwiftUI
import HotKey

// MARK: - Grouped Section

struct GroupedSection<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Menu Row

struct MenuRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    var trailingText: String? = nil
    var action: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 26, height: 26)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)

                Spacer()

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Menu Toggle Row

struct MenuToggleRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(label)
                .font(.system(size: 13, weight: .regular))

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

// MARK: - Inset Divider

struct InsetDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 46)
    }
}

// MARK: - Shortcut Recorder Row

struct ShortcutRecorderRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let currentCombo: KeyCombo
    let onChange: (KeyCombo) -> Void

    @State private var isRecording = false
    @State private var isHovered = false
    @State private var eventMonitor: Any?

    var body: some View {
        Button(action: { toggleRecording() }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 26, height: 26)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)

                Spacer()

                if isRecording {
                    Text("Type shortcut…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.pink)
                } else {
                    Text(comboDisplayString)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isRecording ? Color.pink.opacity(0.06) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        )
        .onHover { hovering in isHovered = hovering }
    }

    private var comboDisplayString: String {
        "\(currentCombo.modifiers)\(currentCombo.key?.description ?? "")"
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = modifiers.contains(.command) || modifiers.contains(.option) || modifiers.contains(.control)

            if event.keyCode == 53 { // Escape
                stopRecording()
                return nil
            }

            guard hasModifier, let key = Key(carbonKeyCode: UInt32(event.keyCode)) else {
                return nil
            }

            var cleanModifiers: NSEvent.ModifierFlags = []
            if modifiers.contains(.command) { cleanModifiers.insert(.command) }
            if modifiers.contains(.shift) { cleanModifiers.insert(.shift) }
            if modifiers.contains(.option) { cleanModifiers.insert(.option) }
            if modifiers.contains(.control) { cleanModifiers.insert(.control) }

            let combo = KeyCombo(key: key, modifiers: cleanModifiers)
            onChange(combo)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
