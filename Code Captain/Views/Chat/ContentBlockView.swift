import SwiftUI
import MarkdownUI

struct ContentBlockView: View {
    let contentBlock: ContentBlock
    
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
        switch contentBlock {
        case .text(let textBlock):
            Markdown(textBlock.text)
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