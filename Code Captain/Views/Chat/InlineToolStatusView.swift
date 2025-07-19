import Shimmer
import SwiftUI

struct InlineToolStatusView: View {
    let toolStatus: ToolStatus
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main status row
            HStack(spacing: 8) {
                // Tool icon
                Image(systemName: toolStatus.customIconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(toolIconColor)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())

                // Status label with chevron right next to it
                HStack(spacing: 6) {
                    statusLabel

                    // Chevron for completed state (on hover or expanded)
                    if toolStatus.isCompleted && (isHovered || isExpanded) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary).opacity(0.75)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(
                                .spring(
                                    response: 0.25,
                                    dampingFraction: 0.9,
                                    blendDuration: 0
                                ),
                                value: isExpanded
                            )
                    }
                }

                Spacer()
            }
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                if toolStatus.isCompleted && toolStatus.fullContent != nil {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9))
                    {
                        isExpanded.toggle()
                    }
                }
            }
            .contentShape(Rectangle())  // Full-width hit area

            // Preview content (processing state) or expanded content (completed state)
            if shouldShowContent {
                contentView
                    .frame(maxHeight: shouldShowContent ? .infinity : 0, alignment: .top)
                    .opacity(shouldShowContent ? 1 : 0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.9), value: shouldShowContent)
                    .clipped() // Prevent content overflow during animation
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Computed Properties

    private var statusLabel: some View {
        Group {
            switch toolStatus.state {
            case .processing:
                Text(toolStatus.processingLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .shimmering()  // Apply shimmer animation

            case .completed:
                Text(toolStatus.completedLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

            case .error(let message):
                Text(toolStatus.errorLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            }
        }
    }

    private var toolIconColor: Color {
        switch toolStatus.state {
        case .processing:
            return Color(string: toolStatus.toolType.color) ?? .primary
        case .completed:
            return .secondary
        case .error:
            return .red
        }
    }

    private var shouldShowContent: Bool {
        if toolStatus.isProcessing && toolStatus.preview != nil {
            return true
        }
        if toolStatus.isCompleted && isExpanded && toolStatus.fullContent != nil
        {
            return true
        }
        return false
    }

    private var contentView: some View {
        Group {
            if toolStatus.isProcessing {
                // Show preview during processing
                if let preview = toolStatus.preview {
                    previewContent(preview)
                }
            } else if toolStatus.isCompleted && isExpanded {
                // Show full content when expanded
                if let fullContent = toolStatus.fullContent {
                    expandedContent(fullContent)
                }
            }
        }
    }

    private func previewContent(_ preview: String) -> some View {
        Text(preview)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .padding(.leading, 24)  // Align with text after icon
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func expandedContent(_ content: String) -> some View {
        ScrollView {
            Text(content)
                .font(.caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 200)
        .padding(.leading, 24)  // Align with text after icon
    }
}

// MARK: - Color Extension
extension Color {
    init?(string: String) {
        switch string.lowercased() {
        case "blue": self = .blue
        case "green": self = .green
        case "orange": self = .orange
        case "purple": self = .purple
        case "red": self = .red
        case "gray": self = .gray
        case "mint": self = .mint
        case "indigo": self = .indigo
        case "teal": self = .teal
        case "yellow": self = .yellow
        case "pink": self = .pink
        case "cyan": self = .cyan
        default: return nil
        }
    }
}

// MARK: - Preview Helpers
extension InlineToolStatusView {
    static var mockProcessingThinking: InlineToolStatusView {
        let toolStatus = ToolStatus(
            id: "thinking-1",
            toolType: .task,
            state: .processing,
            preview:
                "I need to analyze the user's request and determine the best approach. This involves reading the current file structure and understanding the codebase...",
            fullContent: nil,
            startTime: Date()
        )
        return InlineToolStatusView(toolStatus: toolStatus)
    }

    static var mockProcessingBash: InlineToolStatusView {
        let toolStatus = ToolStatus(
            id: "bash-1",
            toolType: .bash,
            state: .processing,
            preview: "git status --porcelain",
            fullContent: nil,
            startTime: Date()
        )
        return InlineToolStatusView(toolStatus: toolStatus)
    }

    static var mockCompletedRead: InlineToolStatusView {
        let toolStatus = ToolStatus(
            id: "read-1",
            toolType: .read,
            state: .completed(duration: 0.5),
            preview: "ChatView.swift",
            fullContent:
                "import SwiftUI\n\nstruct ChatView: View {\n    let sessionId: UUID\n    @ObservedObject var store: CodeCaptainStore\n    // ... rest of file content",
            startTime: Date().addingTimeInterval(-1),
            endTime: Date().addingTimeInterval(-0.5)
        )
        return InlineToolStatusView(toolStatus: toolStatus)
    }
}

// MARK: - Previews
#Preview("Processing - Thinking") {
    InlineToolStatusView.mockProcessingThinking
        .padding()
}

#Preview("Processing - Bash Command") {
    InlineToolStatusView.mockProcessingBash
        .padding()
}

#Preview("Completed - Read File") {
    InlineToolStatusView.mockCompletedRead
        .padding()
}

#Preview("All States") {
    VStack(alignment: .leading, spacing: 16) {
        InlineToolStatusView.mockProcessingThinking
        InlineToolStatusView.mockProcessingBash
        InlineToolStatusView.mockCompletedRead
    }
    .padding()
}
