import SwiftUI

struct RichMessageView: View {
    let message: Message  // Use Message instead of SDKMessage directly
    
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let sdkMessage = message.sdkMessage {
                switch sdkMessage {
                case .assistant(let assistantMsg):
                    // Render each content block with per-message state management
                    ForEach(
                        Array(assistantMsg.message.content.enumerated()),
                        id: \.element.id
                    ) { index, contentBlock in
                        renderContentBlock(contentBlock, at: index)
                    }
                case .user(let userMsg):
                    VStack(alignment: .leading, spacing: 8) {
                        switch userMsg.message.content {
                        case .text(let text):
                            HStack {
                                Spacer(minLength: 60)
                                Text(LocalizedStringKey(convertHeadingsToBold(text)))
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(16)
                            }
                        case .blocks(let blocks):
                            // Filter out tool_result
                            ForEach(blocks.indices, id: \.self) { index in
                                let block = blocks[index]
                                
                                // Only render blocks that are not tool_result
                                if block.type != "tool_result", let content = block.content {
                                    HStack {
                                        Spacer(minLength: 60)
                                        Text(LocalizedStringKey(convertHeadingsToBold(content)))
                                            .font(.body)
                                            .textSelection(.enabled)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                    }
                case .system(let systemMsg):
                    // SystemMessageView(systemMessage: systemMsg) // Commented out to hide system messages in UI
                    EmptyView()
                case .result(let resultMsg):
                    // ResultMessageView(resultMessage: resultMsg) // Commented out to hide result messages in UI
                    EmptyView()
                }
            } else {
                Text("No message content")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Content Rendering

    @ViewBuilder
    private func renderContentBlock(_ contentBlock: ContentBlock, at index: Int)
        -> some View
    {
        switch contentBlock {
        case .thinking(_), .toolUse(_):
            // Find existing status from this message's tool statuses
            if let toolStatus = message.getToolStatus(
                for: contentBlock,
                at: index
            ) {
                InlineToolStatusView(toolStatus: toolStatus)
            } else {
                // Fallback to regular content block view
                ContentBlockView(contentBlock: contentBlock)
            }

        case .text(_):
            // Regular text content - render normally
            ContentBlockView(contentBlock: contentBlock)

        default:
            // Other content types - render normally
            ContentBlockView(contentBlock: contentBlock)
        }
    }

}
