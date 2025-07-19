import SwiftUI

struct ToolUseView: View {
    let toolUse: ToolUseBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: toolIconName)
                    .foregroundColor(toolColor)

                Text(toolDisplayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(toolColor)

                Spacer()

                Text(toolUse.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let inputDescription = formatToolInput() {
                Text(inputDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var toolIconName: String {
        if let toolAction = ToolAction(rawValue: toolUse.name) {
            return toolAction.iconName
        }
        return "wrench.and.screwdriver"
    }

    private var toolColor: Color {
        if let toolAction = ToolAction(rawValue: toolUse.name) {
            switch toolAction.color {
            case "blue": return .blue
            case "green": return .green
            case "orange": return .orange
            case "purple": return .purple
            case "red": return .red
            default: return .primary
            }
        }
        return .primary
    }

    private var toolDisplayName: String {
        if let toolAction = ToolAction(rawValue: toolUse.name) {
            return toolAction.displayName
        }
        return toolUse.name.capitalized
    }

    private func formatToolInput() -> String? {
        // Handle specific tool types with enhanced formatting
        guard let toolAction = ToolAction(rawValue: toolUse.name) else {
            return formatGenericInput()
        }

        switch toolAction {
        // Core CLI Tools
        case .bash:
            if let command = toolUse.input["command"]?.value as? String {
                return "Running: \(command)"
            }

        // Advanced Claude Code Tools
        case .task:
            if let description = toolUse.input["description"]?.value as? String
            {
                return "Task: \(description)"
            }

        case .glob:
            if let pattern = toolUse.input["pattern"]?.value as? String {
                return "Pattern: \(pattern)"
            }

        case .grep:
            if let pattern = toolUse.input["pattern"]?.value as? String {
                let outputMode =
                    toolUse.input["output_mode"]?.value as? String
                    ?? "files_with_matches"
                return "Search: \(pattern) (\(outputMode))"
            }

        case .ls:
            if let path = toolUse.input["path"]?.value as? String {
                return "Directory: \(path)"
            }

        case .read:
            if let filePath = toolUse.input["file_path"]?.value as? String {
                let limit = toolUse.input["limit"]?.value as? Int
                let offset = toolUse.input["offset"]?.value as? Int
                var result = "Reading: \(filePath)"
                if let limit = limit {
                    result += " (limit: \(limit))"
                }
                if let offset = offset {
                    result += " (offset: \(offset))"
                }
                return result
            }

        case .edit:
            if let filePath = toolUse.input["file_path"]?.value as? String {
                let oldString =
                    toolUse.input["old_string"]?.value as? String ?? "content"
                return "Editing: \(filePath) - \(oldString.prefix(30))..."
            }

        case .multiEdit:
            if let filePath = toolUse.input["file_path"]?.value as? String {
                let edits =
                    toolUse.input["edits"]?.value as? [[String: Any]] ?? []
                return "Multi-Edit: \(filePath) (\(edits.count) changes)"
            }

        case .write:
            if let filePath = toolUse.input["file_path"]?.value as? String {
                let content = toolUse.input["content"]?.value as? String ?? ""
                let length = content.count
                return "Writing: \(filePath) (\(length) characters)"
            }

        case .notebookRead:
            if let notebookPath = toolUse.input["notebook_path"]?.value
                as? String
            {
                return "Reading notebook: \(notebookPath)"
            }

        case .notebookEdit:
            if let notebookPath = toolUse.input["notebook_path"]?.value
                as? String
            {
                let editMode =
                    toolUse.input["edit_mode"]?.value as? String ?? "replace"
                return "Editing notebook: \(notebookPath) (\(editMode))"
            }

        case .webFetch:
            if let url = toolUse.input["url"]?.value as? String {
                return "Fetching: \(url)"
            }

        case .todoWrite:
            if let todos = toolUse.input["todos"]?.value as? [[String: Any]] {
                return "Todo list: \(todos.count) items"
            }

        case .webSearch, .webSearchAdvanced:
            if let query = toolUse.input["query"]?.value as? String {
                return "Searching: \(query)"
            }

        // File System Operations
        case .fileRead, .fileWrite, .fileCreate, .fileDelete, .fileMove,
            .fileCopy:
            if let filePath = toolUse.input["file_path"]?.value as? String {
                return "File: \(filePath)"
            }

        case .directoryList, .directoryCreate:
            if let dirPath = toolUse.input["directory_path"]?.value as? String {
                return "Directory: \(dirPath)"
            }

        // Git Operations
        case .gitStatus, .gitAdd, .gitCommit, .gitPush, .gitPull, .gitBranch,
            .gitCheckout, .gitMerge, .gitDiff, .gitLog:
            if let repository = toolUse.input["repository"]?.value as? String {
                return "Repository: \(repository)"
            } else if let branch = toolUse.input["branch"]?.value as? String {
                return "Branch: \(branch)"
            } else if let message = toolUse.input["message"]?.value as? String {
                return "Message: \(message)"
            }

        // Code Analysis
        case .codeAnalysis, .syntaxCheck, .lintCheck, .formatCode,
            .findReferences, .findDefinition:
            if let filePath = toolUse.input["file_path"]?.value as? String {
                return "Analyzing: \(filePath)"
            }

        // Build & Test
        case .buildProject:
            if let projectPath = toolUse.input["project_path"]?.value as? String
            {
                return "Building: \(projectPath)"
            }

        case .runTests:
            if let testPath = toolUse.input["test_path"]?.value as? String {
                return "Testing: \(testPath)"
            }

        case .runCommand:
            if let command = toolUse.input["command"]?.value as? String {
                return "Running: \(command)"
            }

        case .installDependencies:
            if let packageManager = toolUse.input["package_manager"]?.value
                as? String
            {
                return "Installing with: \(packageManager)"
            }

        // Database Operations
        case .dbQuery:
            if let query = toolUse.input["query"]?.value as? String {
                return "Query: \(query.prefix(50))..."
            }

        case .dbSchema:
            if let table = toolUse.input["table"]?.value as? String {
                return "Schema: \(table)"
            }

        case .dbMigration:
            if let migration = toolUse.input["migration"]?.value as? String {
                return "Migration: \(migration)"
            }

        // API & Network
        case .apiRequest:
            if let url = toolUse.input["url"]?.value as? String {
                let method = toolUse.input["method"]?.value as? String ?? "GET"
                return "\(method): \(url)"
            }

        case .curlRequest:
            if let url = toolUse.input["url"]?.value as? String {
                return "curl: \(url)"
            }

        case .pingHost:
            if let host = toolUse.input["host"]?.value as? String {
                return "Ping: \(host)"
            }

        case .dnsLookup:
            if let domain = toolUse.input["domain"]?.value as? String {
                return "DNS: \(domain)"
            }

        // System Operations
        case .systemInfo:
            return "System information"

        case .processInfo:
            if let processName = toolUse.input["process"]?.value as? String {
                return "Process: \(processName)"
            }

        case .memoryUsage:
            return "Memory usage"

        case .diskUsage:
            if let path = toolUse.input["path"]?.value as? String {
                return "Disk usage: \(path)"
            }

        // Legacy tools
        case .strReplaceEditor, .strReplaceBasedEditTool:
            if let filePath = toolUse.input["file_path"]?.value as? String {
                return "Editing: \(filePath)"
            }

        case .exitPlanMode:
            if let plan = toolUse.input["plan"]?.value as? String {
                return "Plan: \(plan.prefix(50))..."
            }
        }

        return formatGenericInput()
    }

    private func formatGenericInput() -> String? {
        // Fallback for generic input formatting
        if let command = toolUse.input["command"]?.value as? String {
            return "Running: \(command)"
        } else if let filePath = toolUse.input["file_path"]?.value as? String {
            return "File: \(filePath)"
        } else if let oldString = toolUse.input["old_string"]?.value as? String
        {
            return "Editing: \(oldString.prefix(50))..."
        } else if let query = toolUse.input["query"]?.value as? String {
            return "Search: \(query)"
        } else if let description = toolUse.input["description"]?.value
            as? String
        {
            return description
        } else if let url = toolUse.input["url"]?.value as? String {
            return "URL: \(url)"
        } else if let path = toolUse.input["path"]?.value as? String {
            return "Path: \(path)"
        }
        return nil
    }
}

struct ToolResultView: View {
    let toolResult: ToolResultBlock
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(
                    systemName: toolResult.is_error == true
                        ? "xmark.circle" : "checkmark.circle"
                )
                .foregroundColor(toolResult.is_error == true ? .red : .green)

                Text(toolResult.is_error == true ? "Error" : "Result")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        toolResult.is_error == true ? .red : .green
                    )

                Spacer()

                if let content = toolResult.content, !content.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(
                            systemName: isExpanded
                                ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if let content = toolResult.content, !content.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    // Show formatted content based on type
                    if isExpanded {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(content)
                                    .font(
                                        .system(.caption, design: .monospaced)
                                    )
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                            }
                        }
                        .frame(maxHeight: 200)
                    } else {
                        Text(formatPreview(content))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private func formatPreview(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        let trimmed = lines.prefix(3).joined(separator: "\n")

        // Special formatting for common result types
        if content.contains("error") || content.contains("Error") {
            return "❌ \(trimmed)"
        } else if content.contains("success") || content.contains("Success") {
            return "✅ \(trimmed)"
        } else if content.contains("warning") || content.contains("Warning") {
            return "⚠️ \(trimmed)"
        } else if content.hasPrefix("[") && content.hasSuffix("]") {
            // JSON array
            return "📊 Array with \(lines.count) items"
        } else if content.hasPrefix("{") && content.hasSuffix("}") {
            // JSON object
            return "📝 Object data"
        } else if content.contains("file") || content.contains("File") {
            return "📄 \(trimmed)"
        } else if content.contains("directory") || content.contains("Directory")
        {
            return "📁 \(trimmed)"
        } else if content.contains("http") || content.contains("https") {
            return "🌐 \(trimmed)"
        } else if content.count > 100 {
            return "\(trimmed)... (\(content.count) characters)"
        } else {
            return trimmed
        }
    }
}

struct ThinkingBlockView: View {
    let thinkingBlock: ThinkingBlock
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                    .font(.system(size: 14, weight: .medium))

                Text("Thinking")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)

                Spacer()

                if !thinkingBlock.thinking.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(
                            systemName: isExpanded
                                ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if !thinkingBlock.thinking.isEmpty {
                if isExpanded {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(thinkingBlock.thinking)
                                .font(.system(.body, design: .default))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 300)
                } else {
                    Text(formatThinkingPreview(thinkingBlock.thinking))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .italic()
                }
            }
        }
    }

    private func formatThinkingPreview(_ thinking: String) -> String {
        let lines = thinking.components(separatedBy: .newlines)
        let trimmed = lines.prefix(2).joined(separator: " ")

        if trimmed.count > 150 {
            return String(trimmed.prefix(150)) + "..."
        } else {
            return trimmed
        }
    }
}

struct UserToolResultView: View {
    let block: MessageContentBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(
                    systemName: block.is_error == true
                        ? "xmark.circle" : "checkmark.circle"
                )
                .foregroundColor(block.is_error == true ? .red : .green)
                .font(.system(size: 14, weight: .medium))

                Text("Tool Result")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(block.is_error == true ? .red : .green)

                Spacer()

                if let toolUseId = block.tool_use_id {
                    Text("ID: \(toolUseId.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                }
            }

            if let content = block.content, !content.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatCommandOutput(content))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }
        }
    }

    private func formatCommandOutput(_ content: String) -> String {
        // Add terminal-style formatting
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "(no output)"
        }
        return content
    }
}

struct ServerToolUseView: View {
    let serverToolUse: ServerToolUseBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)

                Text("Server Tool")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)

                Spacer()

                Text(serverToolUse.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct WebSearchResultView: View {
    let webSearchResult: WebSearchResultBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.purple)

                Text("Web Search")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)

                Spacer()
            }

            Text(webSearchResult.title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(webSearchResult.url)
                .font(.caption)
                .foregroundColor(.blue)

            if let content = webSearchResult.content {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
    }
}

struct SystemMessageView: View {
    let systemMessage: SystemMessage
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.orange)
                    .font(.system(size: 14, weight: .medium))

                Text("System \(systemMessage.subtype.rawValue.capitalized)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(
                        systemName: isExpanded ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption)
                    .foregroundColor(.orange)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let model = systemMessage.model {
                        HStack {
                            Text("Model:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text(model)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let cwd = systemMessage.cwd {
                        HStack {
                            Text("Working Directory:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text(cwd)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }

                    if let tools = systemMessage.tools, !tools.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available Tools (\(tools.count)):")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)

                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(
                                        .flexible(),
                                        spacing: 4
                                    ),
                                    count: 3
                                ),
                                spacing: 2
                            ) {
                                ForEach(tools, id: \.self) { tool in
                                    Text(tool)
                                        .font(.caption)
                                        .fontDesign(.monospaced)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    if let apiKeySource = systemMessage.apiKeySource {
                        HStack {
                            Text("API Key:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text(apiKeySource)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let permissionMode = systemMessage.permissionMode {
                        HStack {
                            Text("Permission Mode:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Text(permissionMode.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            } else {
                HStack {
                    if let model = systemMessage.model {
                        Text("Model: \(model)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let toolCount = systemMessage.tools?.count {
                        Text("• \(toolCount) tools")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct ResultMessageView: View {
    let resultMessage: ResultMessage
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(
                    systemName: resultMessage.is_error
                        ? "xmark.circle" : "checkmark.circle"
                )
                .foregroundColor(resultMessage.is_error ? .red : .green)
                .font(.system(size: 14, weight: .medium))

                Text(resultMessage.is_error ? "Error" : "Session Completed")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(resultMessage.is_error ? .red : .green)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(
                        systemName: isExpanded ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption)
                    .foregroundColor(resultMessage.is_error ? .red : .green)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if let result = resultMessage.result, !result.isEmpty {
                Text(result)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Timing Information
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timing:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(
                                resultMessage.is_error ? .red : .green
                            )

                        HStack {
                            Text("Total Duration:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(
                                "\(String(format: "%.2f", resultMessage.duration_ms / 1000))s"
                            )
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(.primary)
                        }

                        HStack {
                            Text("API Duration:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(
                                "\(String(format: "%.2f", resultMessage.duration_api_ms / 1000))s"
                            )
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(.primary)
                        }
                    }

                    Divider()

                    // Cost and Usage Information
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usage & Cost:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(
                                resultMessage.is_error ? .red : .green
                            )

                        HStack {
                            Text("Turns:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(resultMessage.num_turns)")
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundColor(.primary)

                            Spacer()

                            Text("Total Cost:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(
                                "$\(String(format: "%.4f", resultMessage.total_cost_usd))"
                            )
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(.primary)
                        }

                        if let usage = resultMessage.usage {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("Input Tokens:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(usage.input_tokens)")
                                        .font(.caption)
                                        .fontDesign(.monospaced)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Text("Output Tokens:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(usage.output_tokens)")
                                        .font(.caption)
                                        .fontDesign(.monospaced)
                                        .foregroundColor(.primary)
                                }

                                if let cacheCreation = usage
                                    .cache_creation_input_tokens
                                {
                                    HStack {
                                        Text("Cache Creation:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(cacheCreation)")
                                            .font(.caption)
                                            .fontDesign(.monospaced)
                                            .foregroundColor(.primary)
                                    }
                                }

                                if let cacheRead = usage.cache_read_input_tokens
                                {
                                    HStack {
                                        Text("Cache Read:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(cacheRead)")
                                            .font(.caption)
                                            .fontDesign(.monospaced)
                                            .foregroundColor(.primary)
                                    }
                                }

                                if let serverToolUse = usage.server_tool_use {
                                    HStack {
                                        Text("Web Searches:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(
                                            "\(serverToolUse.web_search_requests)"
                                        )
                                        .font(.caption)
                                        .fontDesign(.monospaced)
                                        .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            } else {
                HStack {
                    Text(
                        "Duration: \(String(format: "%.2f", resultMessage.duration_ms / 1000))s"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text("• Turns: \(resultMessage.num_turns)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(
                        "$\(String(format: "%.4f", resultMessage.total_cost_usd))"
                    )
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}