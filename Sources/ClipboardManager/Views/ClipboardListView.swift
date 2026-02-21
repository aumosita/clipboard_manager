import SwiftUI
import SwiftData

struct ClipboardListView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isKeyboardFocused: Bool

    @Query(
        filter: #Predicate<ClipboardItem> { $0.isPinned },
        sort: \ClipboardItem.timestamp,
        order: .reverse
    )
    private var pinnedItems: [ClipboardItem]

    @Query(
        filter: #Predicate<ClipboardItem> { !$0.isPinned },
        sort: \ClipboardItem.timestamp,
        order: .reverse
    )
    private var recentItems: [ClipboardItem]

    @State private var selectedIndex: Int = 0

    /// Called when user selects an item to paste
    var onPaste: ((String) -> Void)?
    /// Called when the panel should dismiss
    var onDismiss: (() -> Void)?

    private var allItems: [ClipboardItem] {
        pinnedItems + recentItems
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clipboard")
                    .font(.system(size: 14, weight: .semibold))
                Text("panel.title")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(recentItems.count)/100")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if allItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("panel.empty.title")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("panel.empty.subtitle")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            // Pinned section
                            if !pinnedItems.isEmpty {
                                HStack {
                                    Text("panel.section.pinned")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 6)
                                .padding(.bottom, 2)

                                ForEach(Array(pinnedItems.enumerated()), id: \.element.id) { index, item in
                                    ClipboardRowView(
                                        item: item,
                                        isSelected: selectedIndex == index,
                                        onPaste: { pasteItem(item) },
                                        onTogglePin: { togglePin(item) },
                                        onDelete: { deleteItem(item) }
                                    )
                                    .onHover { isHovering in
                                        updateSelectionOnHover(index: index, isHovering: isHovering)
                                    }
                                    .id(item.id)
                                }

                                Divider()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                            }

                            // Recent section
                            if !recentItems.isEmpty {
                                HStack {
                                    Text("panel.section.recent")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, pinnedItems.isEmpty ? 6 : 0)
                                .padding(.bottom, 2)

                                ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                                    let globalIndex = pinnedItems.count + index
                                    ClipboardRowView(
                                        item: item,
                                        isSelected: selectedIndex == globalIndex,
                                        onPaste: { pasteItem(item) },
                                        onTogglePin: { togglePin(item) },
                                        onDelete: { deleteItem(item) }
                                    )
                                    .onHover { isHovering in
                                        updateSelectionOnHover(index: globalIndex, isHovering: isHovering)
                                    }
                                    .id(item.id)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        guard newIndex >= 0, newIndex < allItems.count else { return }
                        withAnimation {
                            proxy.scrollTo(allItems[newIndex].id, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Text("panel.footer.move")
                Text("panel.footer.paste")
                Text("panel.footer.close")
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 6)
        }
        .frame(width: 380, height: 460)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .focusable()
        .focused($isKeyboardFocused)
        .onAppear {
            focusList()
        }
        .onChange(of: allItems.count) { _, _ in
            clampSelection()
        }
        .onMoveCommand { direction in
            switch direction {
            case .up:
                moveSelection(-1)
            case .down:
                moveSelection(1)
            default:
                break
            }
        }
        .onKeyPress(.return) {
            pasteSelected()
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss?()
            return .handled
        }
    }

    // MARK: - Actions

    private func pasteItem(_ item: ClipboardItem) {
        onPaste?(item.content)
    }

    private func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        try? modelContext.save()
    }

    private func deleteItem(_ item: ClipboardItem) {
        modelContext.delete(item)
        try? modelContext.save()
        // Adjust selection if needed
        if selectedIndex >= allItems.count - 1 {
            selectedIndex = max(0, allItems.count - 2)
        }
    }

    private func moveSelection(_ delta: Int) {
        let newIndex = selectedIndex + delta
        if newIndex >= 0 && newIndex < allItems.count {
            selectedIndex = newIndex
        }
    }

    private func pasteSelected() {
        guard !allItems.isEmpty, selectedIndex >= 0, selectedIndex < allItems.count else { return }
        pasteItem(allItems[selectedIndex])
    }

    private func updateSelectionOnHover(index: Int, isHovering: Bool) {
        guard isHovering, index >= 0, index < allItems.count else { return }
        selectedIndex = index
    }

    private func clampSelection() {
        if allItems.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = min(selectedIndex, allItems.count - 1)
        }
        focusList()
    }

    private func focusList() {
        DispatchQueue.main.async {
            isKeyboardFocused = true
        }
    }
}

// MARK: - Visual Effect (NSVisualEffectView wrapper)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
