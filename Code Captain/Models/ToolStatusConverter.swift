import Foundation

// MARK: - Tool Status Converter
/// Converts existing tool blocks to ToolStatus objects for the new inline display
struct ToolStatusConverter {
    
    // MARK: - Convert ToolUseBlock to Processing ToolStatus
    static func convertToProcessingStatus(_ toolUse: ToolUseBlock) -> ToolStatus {
        guard let toolAction = ToolAction(rawValue: toolUse.name) else {
            return ToolStatus(
                id: toolUse.id,
                toolType: .bash, // Fallback
                state: .processing,
                preview: "Unknown tool: \(toolUse.name)",
                fullContent: nil
            )
        }
        
        let preview = generatePreview(for: toolAction, input: toolUse.input)
        let fullContent = generateFullContent(for: toolAction, input: toolUse.input)
        
        return ToolStatus(
            id: toolUse.id,
            toolType: toolAction,
            state: .processing,
            preview: preview,
            fullContent: fullContent
        )
    }
    
    // MARK: - Convert ToolResultBlock to Completed ToolStatus
    static func convertToCompletedStatus(_ toolResult: ToolResultBlock, originalToolUse: ToolUseBlock?) -> ToolStatus {
        let toolAction: ToolAction
        if let originalTool = originalToolUse,
           let action = ToolAction(rawValue: originalTool.name) {
            toolAction = action
        } else {
            toolAction = .bash // Fallback
        }
        
        let preview = originalToolUse.flatMap { generatePreview(for: toolAction, input: $0.input) }
        let fullContent = toolResult.content
        let isError = toolResult.is_error ?? false
        
        let state: ToolStatusState = isError ? 
            .error(message: toolResult.content ?? "Unknown error") :
            .completed(duration: nil) // Duration would need to be calculated externally
        
        return ToolStatus(
            id: toolResult.tool_use_id,
            toolType: toolAction,
            state: state,
            preview: preview,
            fullContent: fullContent
        )
    }
    
    // MARK: - Convert ThinkingBlock to Processing ToolStatus
    static func convertThinkingToStatus(_ thinking: ThinkingBlock) -> ToolStatus {
        let preview = String(thinking.thinking.prefix(100)) + (thinking.thinking.count > 100 ? "..." : "")
        
        return ToolStatus(
            id: UUID().uuidString,
            toolType: .task, // Use task for thinking
            state: .processing,
            preview: preview,
            fullContent: thinking.thinking
        )
    }
    
    // MARK: - Generate Preview Content
    private static func generatePreview(for toolAction: ToolAction, input: [String: AnyCodable]) -> String? {
        switch toolAction {
        case .bash:
            if let command = input["command"]?.value as? String {
                return command
            }
            
        case .read:
            if let filePath = input["file_path"]?.value as? String {
                return URL(fileURLWithPath: filePath).lastPathComponent
            }
            
        case .edit, .multiEdit:
            if let filePath = input["file_path"]?.value as? String {
                return URL(fileURLWithPath: filePath).lastPathComponent
            }
            
        case .write:
            if let filePath = input["file_path"]?.value as? String {
                return URL(fileURLWithPath: filePath).lastPathComponent
            }
            
        case .grep:
            if let pattern = input["pattern"]?.value as? String {
                return "'\(pattern)'"
            }
            
        case .glob:
            if let pattern = input["pattern"]?.value as? String {
                return pattern
            }
            
        case .ls:
            if let path = input["path"]?.value as? String {
                return URL(fileURLWithPath: path).lastPathComponent
            }
            
        case .webFetch:
            if let url = input["url"]?.value as? String {
                return url
            }
            
        case .webSearch, .webSearchAdvanced:
            if let query = input["query"]?.value as? String {
                return "'\(query)'"
            }
            
        case .todoWrite:
            if let todos = input["todos"]?.value as? [[String: Any]] {
                return "\(todos.count) items"
            }
            
        case .gitCommit:
            if let message = input["message"]?.value as? String {
                return "'\(message)'"
            }
            
        case .gitCheckout, .gitBranch:
            if let branch = input["branch"]?.value as? String {
                return branch
            }
            
        case .apiRequest, .curlRequest:
            if let url = input["url"]?.value as? String {
                return url
            }
            
        case .pingHost:
            if let host = input["host"]?.value as? String {
                return host
            }
            
        case .dnsLookup:
            if let domain = input["domain"]?.value as? String {
                return domain
            }
            
        case .dbQuery:
            if let query = input["query"]?.value as? String {
                return String(query.prefix(50)) + (query.count > 50 ? "..." : "")
            }
            
        case .runCommand:
            if let command = input["command"]?.value as? String {
                return command
            }
            
        default:
            // For other tools, try to find a meaningful preview
            if let filePath = input["file_path"]?.value as? String {
                return URL(fileURLWithPath: filePath).lastPathComponent
            } else if let path = input["path"]?.value as? String {
                return URL(fileURLWithPath: path).lastPathComponent
            } else if let description = input["description"]?.value as? String {
                return String(description.prefix(50)) + (description.count > 50 ? "..." : "")
            }
        }
        
        return nil
    }
    
    // MARK: - Generate Full Content for Hover Expansion
    private static func generateFullContent(for toolAction: ToolAction, input: [String: AnyCodable]) -> String? {
        var lines: [String] = []
        
        // Add tool name
        lines.append("Tool: \(toolAction.displayName)")
        
        // Add relevant input parameters
        switch toolAction {
        case .bash, .runCommand:
            if let command = input["command"]?.value as? String {
                lines.append("Command: \(command)")
            }
            
        case .read, .edit, .write:
            if let filePath = input["file_path"]?.value as? String {
                lines.append("File: \(filePath)")
            }
            if toolAction == .edit, let oldString = input["old_string"]?.value as? String {
                lines.append("Replacing: \(String(oldString.prefix(100)))")
            }
            if toolAction == .edit, let newString = input["new_string"]?.value as? String {
                lines.append("With: \(String(newString.prefix(100)))")
            }
            
        case .multiEdit:
            if let filePath = input["file_path"]?.value as? String {
                lines.append("File: \(filePath)")
            }
            if let edits = input["edits"]?.value as? [[String: Any]] {
                lines.append("Changes: \(edits.count) edits")
            }
            
        case .grep:
            if let pattern = input["pattern"]?.value as? String {
                lines.append("Pattern: \(pattern)")
            }
            if let outputMode = input["output_mode"]?.value as? String {
                lines.append("Mode: \(outputMode)")
            }
            
        case .glob:
            if let pattern = input["pattern"]?.value as? String {
                lines.append("Pattern: \(pattern)")
            }
            
        case .webFetch:
            if let url = input["url"]?.value as? String {
                lines.append("URL: \(url)")
            }
            if let prompt = input["prompt"]?.value as? String {
                lines.append("Prompt: \(prompt)")
            }
            
        case .webSearch, .webSearchAdvanced:
            if let query = input["query"]?.value as? String {
                lines.append("Query: \(query)")
            }
            
        case .todoWrite:
            if let todos = input["todos"]?.value as? [[String: Any]] {
                lines.append("Todo Items:")
                for (index, todo) in todos.prefix(5).enumerated() {
                    if let content = todo["content"] as? String {
                        lines.append("  \(index + 1). \(content)")
                    }
                }
                if todos.count > 5 {
                    lines.append("  ... and \(todos.count - 5) more")
                }
            }
            
        default:
            // Add all relevant input parameters for other tools
            for (key, value) in input {
                if let stringValue = value.value as? String {
                    lines.append("\(key.capitalized): \(stringValue)")
                } else if let intValue = value.value as? Int {
                    lines.append("\(key.capitalized): \(intValue)")
                } else if let boolValue = value.value as? Bool {
                    lines.append("\(key.capitalized): \(boolValue)")
                }
            }
        }
        
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

// MARK: - Extension for ContentBlock Integration
extension ToolStatusConverter {
    /// Convert a ContentBlock to ToolStatus for inline display
    static func convertContentBlock(_ contentBlock: ContentBlock) -> ToolStatus? {
        switch contentBlock {
        case .toolUse(let toolUse):
            return convertToProcessingStatus(toolUse)
            
        case .thinking(let thinking):
            return convertThinkingToStatus(thinking)
            
        case .toolResult(let toolResult):
            // For tool results, we need the original tool use to get full context
            // This would typically be managed by the parent view or store
            return convertToCompletedStatus(toolResult, originalToolUse: nil)
            
        default:
            return nil
        }
    }
}