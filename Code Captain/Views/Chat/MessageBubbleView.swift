import SwiftUI

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Rich content blocks or simple text
            if message.hasRichContent {
                RichMessageView(message: message)
            } else {
                // Only show bubble for user messages
                if message.displayIsFromUser {
                    HStack {
                        Spacer(minLength: 60)
                        Text(message.displayContent)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(16)
                    }
                } else {
                    // AI messages: full width, no background
                    Text(message.displayContent)
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