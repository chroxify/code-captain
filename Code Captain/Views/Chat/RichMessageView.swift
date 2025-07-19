import SwiftUI

struct RichMessageView: View {
    let message: Message  // Use Message instead of SDKMessage directly

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let sdkMessage = message.sdkMessage {
                switch sdkMessage {
                case .assistant(let assistantMsg):
                    // Render each content block with per-message state management
                    ForEach(Array(assistantMsg.message.content.enumerated()), id: \.element.id) { index, contentBlock in
                        renderContentBlock(contentBlock, at: index)
                    }
            case .user(let userMsg):
                VStack(alignment: .leading, spacing: 8) {
                    switch userMsg.message.content {
                    case .text(let text):
                        HStack {
                            Spacer(minLength: 60)
                            Text(text)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(16)
                        }
                    case .blocks(let blocks):
                        ForEach(blocks.indices, id: \.self) { index in
                            let block = blocks[index]

                            // Check if this is a tool_result block
                            if block.type == "tool_result" {
                                // Don't display tool_result blocks directly - they are handled by 
                                // the cross-message completion system which updates the original tool
                                // in the assistant message to show as completed
                                EmptyView()
                            } else if let content = block.content {
                                HStack {
                                    Spacer(minLength: 60)
                                    Text(content)
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
                SystemMessageView(systemMessage: systemMsg)
            case .result(let resultMsg):
                ResultMessageView(resultMessage: resultMsg)
                }
            } else {
                Text("No message content")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Content Rendering
    
    @ViewBuilder
    private func renderContentBlock(_ contentBlock: ContentBlock, at index: Int) -> some View {
        switch contentBlock {
        case .thinking(_), .toolUse(_):
            // Find existing status from this message's tool statuses
            if let toolStatus = message.getToolStatus(for: contentBlock, at: index) {
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