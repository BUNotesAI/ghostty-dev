import SwiftUI

/// Action popover content shown when the user clicks the action button on a selected tab.
/// Floats above the terminal pane without affecting layout.
struct SidebarActionPopover: View {
    @ObservedObject var tabManager: SidebarTabManager
    @ObservedObject var snippetStore: SnippetStore
    let theme: SidebarTheme
    @Binding var isPresented: Bool

    @State private var showSnippetEditor = false
    @State private var editingSnippet: Snippet?

    /// Read font size from UserDefaults to match sidebar tab cards.
    private var fontSize: CGFloat {
        let v = UserDefaults.standard.double(forKey: "SidebarFontSize")
        return CGFloat(v > 0 ? v : 12)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Zellij actions
            sectionHeader("Zellij")
            actionButton(
                "Launch Zellij",
                icon: "terminal",
                action: { tabManager.launchZellij(); isPresented = false }
            )
            actionButton(
                "Run CC@Zellij",
                icon: "sparkle",
                action: { tabManager.launchCC(); isPresented = false }
            )
            actionButton(
                "Detach Zellij",
                icon: "arrow.uturn.left",
                action: { tabManager.detachZellij(); isPresented = false }
            )

            Divider().padding(.vertical, 2)

            // Tmux actions
            sectionHeader("tmux")
            actionButton(
                "Launch tmux",
                icon: "terminal",
                action: { tabManager.launchTmux(); isPresented = false }
            )
            actionButton(
                "Run CC@tmux",
                icon: "sparkle",
                action: { tabManager.launchCC(); isPresented = false }
            )
            actionButton(
                "Detach tmux",
                icon: "arrow.uturn.left",
                action: { tabManager.detachTmux(); isPresented = false }
            )

            // Snippets section
            if !snippetStore.snippets.isEmpty {
                Divider()
                    .padding(.vertical, 2)

                ForEach(snippetStore.snippets) { snippet in
                    snippetButton(snippet)
                }
            }
        }
        .padding(8)
        .sheet(isPresented: $showSnippetEditor) {
            SnippetEditorSheet(
                store: snippetStore,
                isPresented: $showSnippetEditor,
                editing: editingSnippet
            )
        }
    }

    @ViewBuilder
    private func snippetButton(_ snippet: Snippet) -> some View {
        Button {
            // Trim trailing newlines so the cursor stays at the end of the command.
            let cmd = snippet.command.trimmingCharacters(in: .newlines)
            tabManager.sendTextToSelectedPane(cmd)
            isPresented = false
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "text.insert")
                    .font(.system(size: fontSize))
                Text(snippet.name)
                    .font(.system(size: fontSize, weight: .medium))
                    .lineLimit(1)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(theme.activeTabBackground)
            .foregroundColor(theme.foreground)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit...") {
                editingSnippet = snippet
                showSnippetEditor = true
            }
            Button("Delete", role: .destructive) {
                snippetStore.delete(snippet)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: fontSize - 1, weight: .semibold))
                .foregroundColor(theme.secondaryText)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: fontSize))
                Text(title)
                    .font(.system(size: fontSize, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(theme.activeTabBackground)
            .foregroundColor(theme.foreground)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
