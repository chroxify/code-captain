import SwiftUI

struct ContentBlockView: View {
    let contentBlock: ContentBlock

    var body: some View {
        switch contentBlock {
        case .text(let textBlock):
            Text(textBlock.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .thinking(let thinkingBlock):
            // Simple fallback thinking display (tool status handling is done at parent level)
            Text(thinkingBlock.thinking)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)

        case .toolUse(let toolUseBlock):
            // Simple fallback tool use display (tool status handling is done at parent level)
            Text("Tool: \(toolUseBlock.name)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .toolResult(let toolResultBlock):
            // Simple fallback tool result display (tool status handling is done at parent level)
            if let content = toolResultBlock.content {
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .serverToolUse(let serverToolUseBlock):
            // Keep original view for server tools for now
            ServerToolUseView(serverToolUse: serverToolUseBlock)

        case .webSearchResult(let webSearchBlock):
            // Keep original view for web search results
            WebSearchResultView(webSearchResult: webSearchBlock)
        }
    }
}