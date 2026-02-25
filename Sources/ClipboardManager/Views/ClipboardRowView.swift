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

            // Content area — click to paste
            Button(action: onPaste) {
                HStack(spacing: 8) {
                    contentIcon
                    contentBody
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

    // MARK: - Content Type Icon

    @ViewBuilder
    private var contentIcon: some View {
        switch item.contentType {
        case .text:
            EmptyView()
        case .image:
            if let nsImage = item.thumbnailImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
        case .file:
            Image(systemName: item.fileURLList.count > 1 ? "doc.on.doc" : "doc")
                .font(.system(size: 18))
                .foregroundStyle(.blue)
                .frame(width: 28)
        }
    }

    // MARK: - Content Body

    @ViewBuilder
    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.displayTitle)
                .font(.system(size: 13))
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                if item.contentType != .text {
                    Text(contentTypeLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(contentTypeLabelColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(contentTypeLabelColor.opacity(0.1))
                        )
                }

                Text(item.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var contentTypeLabel: String {
        switch item.contentType {
        case .text: return ""
        case .image: return String(localized: "row.badge.image", bundle: .main)
        case .file:
            let count = item.fileURLList.count
            return count > 1
                ? String(localized: "row.badge.files", bundle: .main) + " (\(count))"
                : String(localized: "row.badge.file", bundle: .main)
        }
    }

    private var contentTypeLabelColor: Color {
        switch item.contentType {
        case .text: return .primary
        case .image: return .purple
        case .file: return .blue
        }
    }
}
