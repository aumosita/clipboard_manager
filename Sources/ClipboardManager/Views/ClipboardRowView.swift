import SwiftUI
import SwiftData

struct ClipboardRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onPaste: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Pin button
            Button(action: onTogglePin) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundStyle(item.isPinned ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(item.isPinned
                ? String(localized: "row.help.unpin", bundle: .main)
                : String(localized: "row.help.pin", bundle: .main)
            )

            // Text content — click to paste
            Button(action: onPaste) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.content)
                        .font(.system(size: 13))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.timestamp, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "row.help.delete", bundle: .main))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
