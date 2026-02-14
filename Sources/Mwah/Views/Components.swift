import SwiftUI

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
