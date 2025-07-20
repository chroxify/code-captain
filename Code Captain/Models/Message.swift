import Foundation

// MARK: - SDKMessage Types

enum SDKMessage: Codable, Identifiable, Hashable {
    case assistant(AssistantMessage)
    case user(UserMessage)
    case system(SystemMessage)
    case result(ResultMessage)
    
    enum CodingKeys: String, CodingKey {
        case type
        case session_id
        case sessionId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode the type field with fallback handling
        let type: String
        do {
            type = try container.decode(String.self, forKey: .type)
        } catch {
            // If type field is missing, try to infer from available fields
            let allKeys = container.allKeys
            if allKeys.contains(where: { $0.stringValue == "message" }) {
                type = "assistant" // Default to assistant if message field exists
            } else if allKeys.contains(where: { $0.stringValue == "subtype" }) {
                type = "system" // Default to system if subtype field exists
            } else if allKeys.contains(where: { $0.stringValue == "duration_ms" }) {
                type = "result" // Default to result if duration_ms field exists
            } else {
                type = "assistant" // Final fallback
            }
        }
        
        switch type {
        case "assistant":
            do {
                let assistantMessage = try AssistantMessage(from: decoder)
                self = .assistant(assistantMessage)
            } catch {
                // Fallback: create a basic assistant message with error content
                let fallbackMessage = Self.createFallbackAssistantMessage(from: decoder, error: error)
                self = .assistant(fallbackMessage)
            }
        case "user":
            do {
                let userMessage = try UserMessage(from: decoder)
                self = .user(userMessage)
            } catch {
                // Fallback: create a basic user message with error content
                let fallbackMessage = Self.createFallbackUserMessage(from: decoder, error: error)
                self = .user(fallbackMessage)
            }
        case "system":
            do {
                let systemMessage = try SystemMessage(from: decoder)
                self = .system(systemMessage)
            } catch {
                // Fallback: create a basic system message
                let fallbackMessage = Self.createFallbackSystemMessage(from: decoder, error: error)
                self = .system(fallbackMessage)
            }
        case "result":
            do {
                let resultMessage = try ResultMessage(from: decoder)
                self = .result(resultMessage)
            } catch {
                // Fallback: create a basic result message
                let fallbackMessage = Self.createFallbackResultMessage(from: decoder, error: error)
                self = .result(fallbackMessage)
            }
        default:
            // For unknown types, create a fallback assistant message
            let fallbackMessage = Self.createFallbackAssistantMessage(from: decoder, error: nil, unknownType: type)
            self = .assistant(fallbackMessage)
        }
    }
    
    private static func createFallbackAssistantMessage(from decoder: Decoder, error: Error?, unknownType: String? = nil) -> AssistantMessage {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        let sessionId = Self.extractSessionId(from: decoder) ?? "unknown"
        
        let errorText: String
        if let unknownType = unknownType {
            errorText = "Unknown message type: \(unknownType)"
        } else if let error = error {
            errorText = "Parsing error: \(error.localizedDescription)"
        } else {
            errorText = "Unknown parsing error"
        }
        
        let textBlock = TextBlock(text: errorText)
        let anthropicMessage = AnthropicMessage(
            id: UUID().uuidString,
            content: [.text(textBlock)],
            model: nil,
            role: "assistant",
            stop_reason: nil,
            stop_sequence: nil,
            usage: nil
        )
        
        return AssistantMessage(
            message: anthropicMessage,
            session_id: sessionId,
            parent_tool_use_id: nil
        )
    }
    
    private static func createFallbackUserMessage(from decoder: Decoder, error: Error?) -> UserMessage {
        let sessionId = Self.extractSessionId(from: decoder) ?? "unknown"
        let errorText = "User message parsing error: \(error?.localizedDescription ?? "Unknown error")"
        
        let messageParam = MessageParam(
            content: .text(errorText),
            role: "user"
        )
        
        return UserMessage(
            message: messageParam,
            session_id: sessionId,
            parent_tool_use_id: nil
        )
    }
    
    private static func createFallbackSystemMessage(from decoder: Decoder, error: Error?) -> SystemMessage {
        let sessionId = Self.extractSessionId(from: decoder) ?? "unknown"
        
        return SystemMessage(
            subtype: .initMessage,
            session_id: sessionId,
            apiKeySource: nil,
            cwd: nil,
            tools: nil,
            mcp_servers: nil,
            model: nil,
            permissionMode: nil
        )
    }
    
    private static func createFallbackResultMessage(from decoder: Decoder, error: Error?) -> ResultMessage {
        let sessionId = Self.extractSessionId(from: decoder) ?? "unknown"
        let errorText = "Result message parsing error: \(error?.localizedDescription ?? "Unknown error")"
        
        return ResultMessage(
            subtype: .errorDuringExecution,
            duration_ms: 0,
            duration_api_ms: 0,
            is_error: true,
            num_turns: 0,
            session_id: sessionId,
            total_cost_usd: 0,
            result: errorText,
            usage: nil
        )
    }
    
    private static func extractSessionId(from decoder: Decoder) -> String? {
        // Try to extract session_id from various possible locations
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            // Try session_id key
            if let sessionId = try? container.decode(String.self, forKey: .session_id) {
                return sessionId
            }
            
            // Try sessionId key (camelCase variant)
            if let sessionId = try? container.decode(String.self, forKey: .sessionId) {
                return sessionId
            }
        }
        
        // Try single value container
        if let singleValueContainer = try? decoder.singleValueContainer() {
            if let dict = try? singleValueContainer.decode([String: String].self) {
                return dict["session_id"] ?? dict["sessionId"]
            }
        }
        
        return nil
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .assistant(let msg):
            try msg.encode(to: encoder)
        case .user(let msg):
            try msg.encode(to: encoder)
        case .system(let msg):
            try msg.encode(to: encoder)
        case .result(let msg):
            try msg.encode(to: encoder)
        }
    }
    
    var id: String {
        switch self {
        case .assistant(let msg):
            return "\(msg.session_id)_\(msg.message.id ?? UUID().uuidString)"
        case .user(let msg):
            return "\(msg.session_id)_user_\(UUID().uuidString)"
        case .system(let msg):
            return "\(msg.session_id)_system_\(msg.subtype.rawValue)"
        case .result(let msg):
            return "\(msg.session_id)_result_\(msg.subtype.rawValue)"
        }
    }
    
    var sessionId: String {
        switch self {
        case .assistant(let msg): return msg.session_id
        case .user(let msg): return msg.session_id
        case .system(let msg): return msg.session_id
        case .result(let msg): return msg.session_id
        }
    }
    
    var timestamp: Date {
        Date() // Will be set when message is created
    }
}

// MARK: - Assistant Message

struct AssistantMessage: Codable, Hashable {
    let type: String
    let message: AnthropicMessage
    let session_id: String
    let parent_tool_use_id: String?
    
    init(message: AnthropicMessage, session_id: String, parent_tool_use_id: String? = nil) {
        self.type = "assistant"
        self.message = message
        self.session_id = session_id
        self.parent_tool_use_id = parent_tool_use_id
    }
}

struct AnthropicMessage: Codable, Hashable {
    let id: String?
    let content: [ContentBlock]
    let model: String?
    let role: String
    let stop_reason: StopReason?
    let stop_sequence: String?
    let usage: Usage?
}

// MARK: - User Message

struct UserMessage: Codable, Hashable {
    let type: String
    let message: MessageParam
    let session_id: String
    let parent_tool_use_id: String?
    
    init(message: MessageParam, session_id: String, parent_tool_use_id: String? = nil) {
        self.type = "user"
        self.message = message
        self.session_id = session_id
        self.parent_tool_use_id = parent_tool_use_id
    }
}

struct MessageParam: Codable, Hashable {
    let content: MessageContent
    let role: String
}

enum MessageContent: Codable, Hashable {
    case text(String)
    case blocks([MessageContentBlock])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .text(stringValue)
        } else if let blockArray = try? container.decode([MessageContentBlock].self) {
            self = .blocks(blockArray)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode MessageContent"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .blocks(let blocks):
            try container.encode(blocks)
        }
    }
}

struct MessageContentBlock: Codable, Hashable {
    let tool_use_id: String?
    let type: String
    let content: String?
    let is_error: Bool?
}

// MARK: - System Message

struct SystemMessage: Codable, Hashable {
    let type: String
    let subtype: SystemSubtype
    let apiKeySource: String?
    let cwd: String?
    let session_id: String
    let tools: [String]?
    let mcp_servers: [MCPServer]?
    let model: String?
    let permissionMode: PermissionMode?
    
    init(subtype: SystemSubtype, session_id: String, apiKeySource: String? = nil, cwd: String? = nil, tools: [String]? = nil, mcp_servers: [MCPServer]? = nil, model: String? = nil, permissionMode: PermissionMode? = nil) {
        self.type = "system"
        self.subtype = subtype
        self.apiKeySource = apiKeySource
        self.cwd = cwd
        self.session_id = session_id
        self.tools = tools
        self.mcp_servers = mcp_servers
        self.model = model
        self.permissionMode = permissionMode
    }
    
    enum SystemSubtype: String, Codable {
        case initMessage = "init"
    }
    
    enum PermissionMode: String, Codable {
        case `default` = "default"
        case acceptEdits = "acceptEdits"
        case bypassPermissions = "bypassPermissions"
        case plan = "plan"
    }
}

struct MCPServer: Codable, Hashable {
    let name: String
    let status: String
}

// MARK: - Result Message

struct ResultMessage: Codable, Hashable {
    let type: String
    let subtype: ResultSubtype
    let duration_ms: Double
    let duration_api_ms: Double
    let is_error: Bool
    let num_turns: Int
    let session_id: String
    let total_cost_usd: Double
    let result: String?
    let usage: Usage?
    
    init(subtype: ResultSubtype, duration_ms: Double, duration_api_ms: Double, is_error: Bool, num_turns: Int, session_id: String, total_cost_usd: Double, result: String? = nil, usage: Usage? = nil) {
        self.type = "result"
        self.subtype = subtype
        self.duration_ms = duration_ms
        self.duration_api_ms = duration_api_ms
        self.is_error = is_error
        self.num_turns = num_turns
        self.session_id = session_id
        self.total_cost_usd = total_cost_usd
        self.result = result
        self.usage = usage
    }
    
    enum ResultSubtype: String, Codable {
        case success = "success"
        case errorMaxTurns = "error_max_turns"
        case errorDuringExecution = "error_during_execution"
    }
}

// MARK: - Content Blocks

enum ContentBlock: Codable, Identifiable, Hashable {
    case text(TextBlock)
    case thinking(ThinkingBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
    case serverToolUse(ServerToolUseBlock)
    case webSearchResult(WebSearchResultBlock)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let textBlock = try TextBlock(from: decoder)
            self = .text(textBlock)
        case "thinking":
            let thinkingBlock = try ThinkingBlock(from: decoder)
            self = .thinking(thinkingBlock)
        case "tool_use":
            let toolUseBlock = try ToolUseBlock(from: decoder)
            self = .toolUse(toolUseBlock)
        case "tool_result":
            let toolResultBlock = try ToolResultBlock(from: decoder)
            self = .toolResult(toolResultBlock)
        case "server_tool_use":
            let serverToolUseBlock = try ServerToolUseBlock(from: decoder)
            self = .serverToolUse(serverToolUseBlock)
        case "web_search_result":
            let webSearchResultBlock = try WebSearchResultBlock(from: decoder)
            self = .webSearchResult(webSearchResultBlock)
        default:
            // For unknown types, try to decode as a generic text block
            let fallbackText = "Unknown content block type: \(type)"
            let fallbackBlock = TextBlock(text: fallbackText)
            self = .text(fallbackBlock)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block):
            try block.encode(to: encoder)
        case .thinking(let block):
            try block.encode(to: encoder)
        case .toolUse(let block):
            try block.encode(to: encoder)
        case .toolResult(let block):
            try block.encode(to: encoder)
        case .serverToolUse(let block):
            try block.encode(to: encoder)
        case .webSearchResult(let block):
            try block.encode(to: encoder)
        }
    }
    
    var id: String {
        switch self {
        case .text(let block):
            return "text_\(block.text.prefix(20).hash)"
        case .thinking(let block):
            return "thinking_\(block.thinking.prefix(20).hash)"
        case .toolUse(let block):
            return block.id
        case .toolResult(let block):
            return "result_\(block.tool_use_id)"
        case .serverToolUse(let block):
            return block.id
        case .webSearchResult(let block):
            return "search_\(block.title.prefix(20).hash)"
        }
    }
    
    var type: ContentBlockType {
        switch self {
        case .text: return .text
        case .thinking: return .thinking
        case .toolUse: return .toolUse
        case .toolResult: return .toolResult
        case .serverToolUse: return .serverToolUse
        case .webSearchResult: return .webSearchResult
        }
    }
}

enum ContentBlockType: String, CaseIterable {
    case text = "text"
    case thinking = "thinking"
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case serverToolUse = "server_tool_use"
    case webSearchResult = "web_search_result"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .thinking: return "Thinking"
        case .toolUse: return "Tool Use"
        case .toolResult: return "Tool Result"
        case .serverToolUse: return "Server Tool"
        case .webSearchResult: return "Web Search"
        }
    }
    
    var iconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .thinking: return "brain.head.profile"
        case .toolUse: return "wrench.and.screwdriver"
        case .toolResult: return "checkmark.circle"
        case .serverToolUse: return "server.rack"
        case .webSearchResult: return "globe"
        }
    }
}

struct TextBlock: Codable, Hashable {
    let text: String
    let type: String
    let citations: [TextCitation]?
    
    init(text: String, citations: [TextCitation]? = nil) {
        self.text = text
        self.type = "text"
        self.citations = citations
    }
}

struct TextCitation: Codable, Hashable {
    // Simplified for now - can be expanded based on actual usage
    let cited_text: String
    let document_index: Int
    let document_title: String?
}

struct ThinkingBlock: Codable, Hashable {
    let thinking: String
    let type: String
    let signature: String?
    
    init(thinking: String, signature: String? = nil) {
        self.thinking = thinking
        self.type = "thinking"
        self.signature = signature
    }
}

struct ToolUseBlock: Codable, Hashable {
    let id: String
    let name: String
    let input: [String: AnyCodable]
    let type: String
    
    init(id: String, name: String, input: [String: AnyCodable]) {
        self.id = id
        self.name = name
        self.input = input
        self.type = "tool_use"
    }
}

struct ToolResultBlock: Codable, Hashable {
    let tool_use_id: String
    let content: String?
    let is_error: Bool?
    let type: String
    
    init(tool_use_id: String, content: String? = nil, is_error: Bool? = nil) {
        self.tool_use_id = tool_use_id
        self.content = content
        self.is_error = is_error
        self.type = "tool_result"
    }
}

struct ServerToolUseBlock: Codable, Hashable {
    let id: String
    let name: String
    let input: [String: AnyCodable]
    let type: String
    
    init(id: String, name: String, input: [String: AnyCodable]) {
        self.id = id
        self.name = name
        self.input = input
        self.type = "server_tool_use"
    }
}

struct WebSearchResultBlock: Codable, Hashable {
    let title: String
    let url: String
    let content: String?
    let type: String
    
    init(title: String, url: String, content: String? = nil) {
        self.title = title
        self.url = url
        self.content = content
        self.type = "web_search_result"
    }
}

// MARK: - Supporting Types

enum StopReason: String, Codable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
    case toolUse = "tool_use"
    case pauseTurn = "pause_turn"
    case refusal = "refusal"
}

struct Usage: Codable, Hashable {
    let input_tokens: Int
    let output_tokens: Int
    let cache_creation_input_tokens: Int?
    let cache_read_input_tokens: Int?
    let server_tool_use: ServerToolUse?
    let service_tier: String?
}

struct ServerToolUse: Codable, Hashable {
    let web_search_requests: Int
}

// MARK: - Helper for Any Codable

struct AnyCodable: Codable, Hashable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode value"))
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch value {
        case let intValue as Int:
            hasher.combine(intValue)
        case let doubleValue as Double:
            hasher.combine(doubleValue)
        case let stringValue as String:
            hasher.combine(stringValue)
        case let boolValue as Bool:
            hasher.combine(boolValue)
        default:
            hasher.combine(0) // Fallback for complex types
        }
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (let lhsInt as Int, let rhsInt as Int):
            return lhsInt == rhsInt
        case (let lhsDouble as Double, let rhsDouble as Double):
            return lhsDouble == rhsDouble
        case (let lhsString as String, let rhsString as String):
            return lhsString == rhsString
        case (let lhsBool as Bool, let rhsBool as Bool):
            return lhsBool == rhsBool
        default:
            return false // Fallback for complex types
        }
    }
}

// MARK: - Legacy Message Support

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let sessionId: UUID
    let content: String
    let role: MessageRole
    let timestamp: Date
    var metadata: MessageMetadata?
    var sdkMessage: SDKMessage?
    var isStreaming: Bool = false
    var toolStatuses: [ToolStatus] = [] // Per-message tool status storage
    
    init(sessionId: UUID, content: String, role: MessageRole, metadata: MessageMetadata? = nil) {
        self.id = UUID()
        self.sessionId = sessionId
        self.content = content
        self.role = role
        self.timestamp = Date()
        self.metadata = metadata
    }
    
    init(from sdkMessage: SDKMessage, sessionId: UUID) {
        self.id = UUID()
        self.sessionId = sessionId
        self.sdkMessage = sdkMessage
        self.timestamp = Date()
        
        switch sdkMessage {
        case .assistant(let msg):
            self.role = .assistant
            self.content = msg.message.content.compactMap { contentBlock in
                switch contentBlock {
                case .text(let textBlock):
                    return textBlock.text
                case .thinking(let thinkingBlock):
                    return thinkingBlock.thinking
                default:
                    return nil
                }
            }.joined(separator: "\n")
            
        case .user(let msg):
            self.role = .user
            switch msg.message.content {
            case .text(let text):
                self.content = text
            case .blocks(let blocks):
                self.content = blocks.compactMap { $0.content }.joined(separator: "\n")
            }
            
        case .system(let msg):
            self.role = .system
            self.content = "System: \(msg.subtype.rawValue)"
            
        case .result(let msg):
            self.role = .system
            self.content = msg.result ?? "Completed in \(msg.duration_ms)ms"
            self.metadata = MessageMetadata(
                processingTime: msg.duration_ms / 1000.0,
                errorInfo: msg.is_error ? "Error occurred" : nil
            )
        }
    }
    
    var isFromUser: Bool {
        role == .user
    }
    
    var isFromAssistant: Bool {
        role == .assistant
    }
    
    /// Display version of isFromUser that respects displayRole override
    var displayIsFromUser: Bool {
        displayRole == .user
    }
    
    /// Display version of isFromAssistant that respects displayRole override
    var displayIsFromAssistant: Bool {
        displayRole == .assistant
    }
    
    var displayContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// The role to display in the UI - overrides user role to system for tool results
    var displayRole: MessageRole {
        // Check if this is a user message containing tool results (Claude Code CLI bug)
        if role == .user, let sdkMessage = sdkMessage {
            if case .user(let userMessage) = sdkMessage {
                // Check if the user message contains tool_result content blocks
                switch userMessage.message.content {
                case .blocks(let contentBlocks):
                    let hasToolResults = contentBlocks.contains { block in
                        block.type == "tool_result"
                    }
                    if hasToolResults {
                        // Override display role to system since users can't send tool results
                        return .system
                    }
                case .text(_):
                    break
                }
            }
        }
        
        // Return original role for all other cases
        return role
    }
    
    var hasRichContent: Bool {
        if let sdkMessage = sdkMessage {
            switch sdkMessage {
            case .assistant(let msg):
                // Always show rich content for assistant messages to display tool_use blocks
                return true
            case .user(let msg):
                // Always show rich content for user messages to display tool_result blocks
                return true
            case .system(_):
                // Always show rich content for system messages to display init info
                return true
            case .result(_):
                // Always show rich content for result messages to display cost/timing stats
                return true
            }
        }
        return false
    }
    
    // MARK: - Tool Status Management
    
    /// Process and update tool statuses for this message
    mutating func processToolStatuses() {
        guard let sdkMessage = self.sdkMessage else { return }
        
        let manager = MessageToolStatusManager(messageId: self.id)
        
        switch sdkMessage {
        case .assistant(let assistantMessage):
            // Only process assistant messages to create tool statuses
            let newStatuses = manager.processContentBlocks(assistantMessage.message.content)
            self.toolStatuses = newStatuses
            
        case .user(_):
            // User messages don't create their own tool statuses
            // Tool completion is handled at the session level
            break
            
        default:
            break
        }
    }
    
    /// Get tool status by content block
    func getToolStatus(for contentBlock: ContentBlock, at index: Int) -> ToolStatus? {
        let messagePrefix = id.uuidString.prefix(8)
        let uniqueId: String
        
        switch contentBlock {
        case .thinking(_):
            uniqueId = "\(messagePrefix)-thinking-\(index)"
        case .toolUse(let toolUse):
            uniqueId = "\(messagePrefix)-tool-\(toolUse.id)"
        case .text(_):
            uniqueId = "\(messagePrefix)-text-\(index)"
        default:
            uniqueId = "\(messagePrefix)-block-\(index)"
        }
        
        return toolStatuses.first { $0.id == uniqueId }
    }
    
    // MARK: - File State Methods
    
    /// Check if this message has file state available for rollback
    var hasFileState: Bool {
        return metadata?.hasFileState == true
    }
    
    /// Set file state availability for this message
    mutating func setFileStateAvailable(_ available: Bool) {
        if metadata == nil {
            metadata = MessageMetadata()
        }
        metadata?.hasFileState = available
    }
}

enum MessageRole: String, CaseIterable, Codable, Hashable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .user: return "You"
        case .assistant: return "Claude"
        case .system: return "System"
        }
    }
}

struct MessageMetadata: Codable, Hashable {
    var filesChanged: [String]?
    var gitOperations: [String]?
    var toolsUsed: [String]?
    var processingTime: TimeInterval?
    var errorInfo: String?
    var hasFileState: Bool?
    
    init(filesChanged: [String]? = nil, gitOperations: [String]? = nil, toolsUsed: [String]? = nil, processingTime: TimeInterval? = nil, errorInfo: String? = nil, hasFileState: Bool? = nil) {
        self.filesChanged = filesChanged
        self.gitOperations = gitOperations
        self.toolsUsed = toolsUsed
        self.processingTime = processingTime
        self.errorInfo = errorInfo
        self.hasFileState = hasFileState
    }
}

// MARK: - Tool Action Types

enum ToolAction: String, CaseIterable, Codable {
    // Core CLI Tools
    case bash = "bash"
    case strReplaceEditor = "str_replace_editor"
    case strReplaceBasedEditTool = "str_replace_based_edit_tool"
    case webSearch = "web_search"
    
    // Advanced Claude Code Tools
    case task = "Task"
    case glob = "Glob"
    case grep = "Grep"
    case ls = "LS"
    case exitPlanMode = "exit_plan_mode"
    case read = "Read"
    case edit = "Edit"
    case multiEdit = "MultiEdit"
    case write = "Write"
    case notebookRead = "NotebookRead"
    case notebookEdit = "NotebookEdit"
    case webFetch = "WebFetch"
    case todoWrite = "TodoWrite"
    case webSearchAdvanced = "WebSearch"
    
    // File System Operations
    case fileRead = "file_read"
    case fileWrite = "file_write"
    case fileCreate = "file_create"
    case fileDelete = "file_delete"
    case fileMove = "file_move"
    case fileCopy = "file_copy"
    case directoryList = "directory_list"
    case directoryCreate = "directory_create"
    
    // Git Operations
    case gitStatus = "git_status"
    case gitAdd = "git_add"
    case gitCommit = "git_commit"
    case gitPush = "git_push"
    case gitPull = "git_pull"
    case gitBranch = "git_branch"
    case gitCheckout = "git_checkout"
    case gitMerge = "git_merge"
    case gitDiff = "git_diff"
    case gitLog = "git_log"
    
    // Code Analysis
    case codeAnalysis = "code_analysis"
    case syntaxCheck = "syntax_check"
    case lintCheck = "lint_check"
    case formatCode = "format_code"
    case findReferences = "find_references"
    case findDefinition = "find_definition"
    
    // Build & Test
    case buildProject = "build_project"
    case runTests = "run_tests"
    case runCommand = "run_command"
    case installDependencies = "install_dependencies"
    
    // Database Operations
    case dbQuery = "db_query"
    case dbSchema = "db_schema"
    case dbMigration = "db_migration"
    
    // API & Network
    case apiRequest = "api_request"
    case curlRequest = "curl_request"
    case pingHost = "ping_host"
    case dnsLookup = "dns_lookup"
    
    // System Operations
    case systemInfo = "system_info"
    case processInfo = "process_info"
    case memoryUsage = "memory_usage"
    case diskUsage = "disk_usage"
    
    var displayName: String {
        switch self {
        // Core CLI Tools
        case .bash: return "Terminal"
        case .strReplaceEditor: return "File Editor"
        case .strReplaceBasedEditTool: return "Code Editor"
        case .webSearch: return "Web Search"
        
        // Advanced Claude Code Tools
        case .task: return "Task Manager"
        case .glob: return "File Pattern Search"
        case .grep: return "Text Search"
        case .ls: return "Directory Listing"
        case .exitPlanMode: return "Exit Plan Mode"
        case .read: return "Read File"
        case .edit: return "Edit File"
        case .multiEdit: return "Multi-File Edit"
        case .write: return "Write File"
        case .notebookRead: return "Read Notebook"
        case .notebookEdit: return "Edit Notebook"
        case .webFetch: return "Web Fetch"
        case .todoWrite: return "Todo Manager"
        case .webSearchAdvanced: return "Advanced Web Search"
        
        // File System Operations
        case .fileRead: return "Read File"
        case .fileWrite: return "Write File"
        case .fileCreate: return "Create File"
        case .fileDelete: return "Delete File"
        case .fileMove: return "Move File"
        case .fileCopy: return "Copy File"
        case .directoryList: return "List Directory"
        case .directoryCreate: return "Create Directory"
        
        // Git Operations
        case .gitStatus: return "Git Status"
        case .gitAdd: return "Git Add"
        case .gitCommit: return "Git Commit"
        case .gitPush: return "Git Push"
        case .gitPull: return "Git Pull"
        case .gitBranch: return "Git Branch"
        case .gitCheckout: return "Git Checkout"
        case .gitMerge: return "Git Merge"
        case .gitDiff: return "Git Diff"
        case .gitLog: return "Git Log"
        
        // Code Analysis
        case .codeAnalysis: return "Code Analysis"
        case .syntaxCheck: return "Syntax Check"
        case .lintCheck: return "Lint Check"
        case .formatCode: return "Format Code"
        case .findReferences: return "Find References"
        case .findDefinition: return "Find Definition"
        
        // Build & Test
        case .buildProject: return "Build Project"
        case .runTests: return "Run Tests"
        case .runCommand: return "Run Command"
        case .installDependencies: return "Install Dependencies"
        
        // Database Operations
        case .dbQuery: return "Database Query"
        case .dbSchema: return "Database Schema"
        case .dbMigration: return "Database Migration"
        
        // API & Network
        case .apiRequest: return "API Request"
        case .curlRequest: return "HTTP Request"
        case .pingHost: return "Ping Host"
        case .dnsLookup: return "DNS Lookup"
        
        // System Operations
        case .systemInfo: return "System Info"
        case .processInfo: return "Process Info"
        case .memoryUsage: return "Memory Usage"
        case .diskUsage: return "Disk Usage"
        }
    }
    
    var iconName: String {
        switch self {
        // Core CLI Tools
        case .bash: return "terminal"
        case .strReplaceEditor: return "pencil"
        case .strReplaceBasedEditTool: return "pencil.and.outline"
        case .webSearch: return "globe"
        
        // Advanced Claude Code Tools
        case .task: return "list.bullet.rectangle"
        case .glob: return "magnifyingglass.circle"
        case .grep: return "text.magnifyingglass"
        case .ls: return "folder"
        case .exitPlanMode: return "arrow.right.square"
        case .read: return "doc.text"
        case .edit: return "pencil"
        case .multiEdit: return "pencil.and.outline"
        case .write: return "square.and.pencil"
        case .notebookRead: return "book"
        case .notebookEdit: return "book.closed"
        case .webFetch: return "arrow.down.circle"
        case .todoWrite: return "checklist"
        case .webSearchAdvanced: return "globe.americas"
        
        // File System Operations
        case .fileRead: return "doc.text"
        case .fileWrite: return "square.and.pencil"
        case .fileCreate: return "plus.circle"
        case .fileDelete: return "trash"
        case .fileMove: return "arrow.right.circle"
        case .fileCopy: return "doc.on.doc"
        case .directoryList: return "folder"
        case .directoryCreate: return "folder.badge.plus"
        
        // Git Operations
        case .gitStatus: return "info.circle"
        case .gitAdd: return "plus.circle"
        case .gitCommit: return "checkmark.circle"
        case .gitPush: return "arrow.up.circle"
        case .gitPull: return "arrow.down.circle"
        case .gitBranch: return "arrow.triangle.branch"
        case .gitCheckout: return "arrow.triangle.swap"
        case .gitMerge: return "arrow.triangle.merge"
        case .gitDiff: return "doc.plaintext"
        case .gitLog: return "clock"
        
        // Code Analysis
        case .codeAnalysis: return "magnifyingglass"
        case .syntaxCheck: return "checkmark.seal"
        case .lintCheck: return "checkmark.circle"
        case .formatCode: return "textformat"
        case .findReferences: return "link"
        case .findDefinition: return "target"
        
        // Build & Test
        case .buildProject: return "hammer"
        case .runTests: return "play.circle"
        case .runCommand: return "play.rectangle"
        case .installDependencies: return "square.and.arrow.down"
        
        // Database Operations
        case .dbQuery: return "cylinder"
        case .dbSchema: return "cylinder.split.1x2"
        case .dbMigration: return "arrow.up.arrow.down"
        
        // API & Network
        case .apiRequest: return "network"
        case .curlRequest: return "arrow.left.arrow.right"
        case .pingHost: return "wifi"
        case .dnsLookup: return "globe"
        
        // System Operations
        case .systemInfo: return "info.circle"
        case .processInfo: return "cpu"
        case .memoryUsage: return "memorychip"
        case .diskUsage: return "internaldrive"
        }
    }
    
    var color: String {
        switch self {
        // Core CLI Tools
        case .bash: return "blue"
        case .strReplaceEditor: return "green"
        case .strReplaceBasedEditTool: return "orange"
        case .webSearch: return "purple"
        
        // Advanced Claude Code Tools
        case .task: return "indigo"
        case .glob: return "teal"
        case .grep: return "cyan"
        case .ls: return "brown"
        case .exitPlanMode: return "red"
        case .read: return "blue"
        case .edit: return "green"
        case .multiEdit: return "orange"
        case .write: return "purple"
        case .notebookRead: return "indigo"
        case .notebookEdit: return "pink"
        case .webFetch: return "teal"
        case .todoWrite: return "yellow"
        case .webSearchAdvanced: return "purple"
        
        // File System Operations
        case .fileRead: return "blue"
        case .fileWrite: return "green"
        case .fileCreate: return "mint"
        case .fileDelete: return "red"
        case .fileMove: return "orange"
        case .fileCopy: return "cyan"
        case .directoryList: return "brown"
        case .directoryCreate: return "mint"
        
        // Git Operations
        case .gitStatus: return "blue"
        case .gitAdd: return "green"
        case .gitCommit: return "purple"
        case .gitPush: return "red"
        case .gitPull: return "orange"
        case .gitBranch: return "teal"
        case .gitCheckout: return "indigo"
        case .gitMerge: return "pink"
        case .gitDiff: return "yellow"
        case .gitLog: return "brown"
        
        // Code Analysis
        case .codeAnalysis: return "purple"
        case .syntaxCheck: return "green"
        case .lintCheck: return "orange"
        case .formatCode: return "blue"
        case .findReferences: return "teal"
        case .findDefinition: return "indigo"
        
        // Build & Test
        case .buildProject: return "orange"
        case .runTests: return "green"
        case .runCommand: return "blue"
        case .installDependencies: return "purple"
        
        // Database Operations
        case .dbQuery: return "blue"
        case .dbSchema: return "teal"
        case .dbMigration: return "orange"
        
        // API & Network
        case .apiRequest: return "purple"
        case .curlRequest: return "blue"
        case .pingHost: return "green"
        case .dnsLookup: return "teal"
        
        // System Operations
        case .systemInfo: return "blue"
        case .processInfo: return "orange"
        case .memoryUsage: return "red"
        case .diskUsage: return "purple"
        }
    }
}

// MARK: - File Operation Types

enum FileOperation: String {
    case read = "read"
    case write = "write"
    case create = "create"
    case delete = "delete"
    case rename = "rename"
    case view = "view"
    
    var displayName: String {
        switch self {
        case .read: return "Read"
        case .write: return "Write"
        case .create: return "Create"
        case .delete: return "Delete"
        case .rename: return "Rename"
        case .view: return "View"
        }
    }
    
    var iconName: String {
        switch self {
        case .read: return "doc.text"
        case .write: return "pencil"
        case .create: return "plus.circle"
        case .delete: return "trash"
        case .rename: return "arrow.triangle.2.circlepath"
        case .view: return "eye"
        }
    }
    
    var color: String {
        switch self {
        case .read: return "blue"
        case .write: return "green"
        case .create: return "mint"
        case .delete: return "red"
        case .rename: return "orange"
        case .view: return "gray"
        }
    }
}

extension Message {
    static let mockUser = Message(
        sessionId: UUID(),
        content: "Can you help me fix this bug in my React component?",
        role: .user
    )
    
    static let mockAssistant = Message(
        sessionId: UUID(),
        content: "I'd be happy to help you fix the bug in your React component. Let me first examine the component to understand the issue.",
        role: .assistant,
        metadata: MessageMetadata(toolsUsed: ["Read", "Analyze"])
    )
}