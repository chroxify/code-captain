import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    
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
                            Text(LocalizedStringKey(convertHeadingsToBold(message.displayContent)))
                                .font(.body)
                                .textSelection(.enabled)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(16)
                        }
                    } else {
                        // AI messages: full width, no background with Markdown rendering
                        Text(LocalizedStringKey(convertHeadingsToBold(message.displayContent)))
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Metadata
                if let metadata = message.metadata {
                    MessageMetadataView(metadata: metadata)
                }
            }
        }
    }
}
