import SwiftUI
import MarkdownUI

struct MessageBubbleView: View {
    let message: Message
    let sessionMessages: [Message] // Pass the session messages to find next checkpoint
    let store: CodeCaptainStore // Pass the store for checkpoint operations
    private let logger = Logger.shared
    
    // Find the next AI message with file state after this user message
    private var nextFileStateMessage: Message? {
        guard message.role == .user else { return nil }
        
        // Find current message index
        guard let currentIndex = sessionMessages.firstIndex(where: { $0.id == message.id }) else { return nil }
        
        // Look for the next assistant message with file state
        for index in (currentIndex + 1)..<sessionMessages.count {
            let nextMessage = sessionMessages[index]
            if nextMessage.role == .assistant && nextMessage.hasFileState {
                return nextMessage
            }
        }
        
        return nil
    }
    
    // Convert Markdown headings to bold text
    private func convertHeadingsToBold(_ text: String) -> String {
        // Convert # ## ### #### ##### ###### headings to bold
        let pattern = "^(#{1,6})\\s+(.+)$"
        let regex = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let range = NSRange(location: 0, length: text.utf16.count)
        
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: "**$2**"
        )
    }
    
    // Check if message has any visible content
    private var hasVisibleContent: Bool {
        if message.hasRichContent {
            // Check if RichMessageView would render anything
            guard let sdkMessage = message.sdkMessage else { return false }
            
            switch sdkMessage {
            case .assistant(let assistantMsg):
                return assistantMsg.message.content.contains { contentBlock in
                    switch contentBlock {
                    case .thinking(_), .toolUse(_):
                        return message.getToolStatus(for: contentBlock, at: 0) != nil
                    case .text(_):
                        return true
                    default:
                        return true
                    }
                }
            case .user(let userMsg):
                switch userMsg.message.content {
                case .text(let text):
                    return !text.isEmpty
                case .blocks(let blocks):
                    return blocks.contains { block in
                        block.type != "tool_result" && block.content?.isEmpty == false
                    }
                }
            case .system(_):
                return false // Hide system messages (init messages)
            case .result(_):
                return false // Hide result messages (session completion)
            }
        } else {
            return !message.displayContent.isEmpty
        }
    }

    var body: some View {
        // Only render if message has visible content
        if hasVisibleContent {
            VStack(alignment: .leading, spacing: 8) {
                // Rich content blocks or simple text
                if message.hasRichContent {
                    RichMessageView(message: message)
                } else {
                    // Only show bubble for user messages
                    if message.displayIsFromUser {
                        HStack {
                            Spacer(minLength: 60)
                            Markdown(message.displayContent)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(16)
                        }
                    } else {
                        // AI messages: full width, no background with native Markdown rendering
                        Markdown(message.displayContent)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Metadata
                if let metadata = message.metadata {
                    MessageMetadataView(metadata: metadata)
                }
                
                // File state reset button (only visible when there are actual file changes to reset)
                if message.role == .user, 
                   let fileStateMessage = nextFileStateMessage,
                   let session = store.sessions.first(where: { $0.id == fileStateMessage.sessionId }),
                   store.messageHasFileChanges(messageId: fileStateMessage.id, sessionId: session.id) {
                    HStack {
                        Spacer()
                        FileStateResetButton(message: fileStateMessage, store: store)
                    }
                }
            }
        }
    }
}

// MARK: - File State Reset Button

struct FileStateResetButton: View {
    let message: Message
    let store: CodeCaptainStore
    @State private var showingResetConfirmation = false
    @State private var isResetting = false
    
    private var session: Session? {
        store.sessions.first { $0.id == message.sessionId }
    }
    
    private var hasFileChanges: Bool {
        guard let session = session else { return false }
        // Check if THIS MESSAGE specifically has file changes that can be rolled back
        return store.messageHasFileChanges(messageId: message.id, sessionId: session.id)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Button(action: {
                showingResetConfirmation = true
            }) {
                Text("Reset")
                    .font(.caption2)
                    .foregroundColor(hasFileChanges && !isResetting ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!hasFileChanges || isResetting)
            
            if isResetting {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(6)
        .confirmationDialog(
            "Reset to Checkpoint",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset All Changes", role: .destructive) {
                Task {
                    await performReset()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            VStack(alignment: .leading, spacing: 4) {
                Text("This will undo all file changes made by the AI after this checkpoint.")
                
                if let session = session {
                    let checkpointCount = store.getCheckpointRollbackCount(targetMessageId: message.id, session: session)
                    if checkpointCount > 1 {
                        Text("⚠️ This will reset \(checkpointCount) checkpoints back to this message.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("This will reset changes from this checkpoint only.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func performReset() async {
        guard let session = session else { return }
        
        isResetting = true
        
        do {
            // Perform rollback of file changes for this specific message
            await store.rollbackMessage(messageId: message.id, session: session)
            
            // Show success feedback
            // TODO: Add success notification
            
        } catch {
            // Show error feedback
            print("Failed to reset file changes: \(error)")
            // TODO: Add error notification
        }
        
        isResetting = false
    }
}
