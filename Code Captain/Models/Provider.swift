import Foundation

protocol CodeAssistantProvider: AnyObject {
    var name: String { get }
    var version: String { get }
    var supportedFeatures: Set<ProviderFeature> { get }
    var isAvailable: Bool { get }
    
    /// Create a new session and return the provider-specific session ID
    func createSession(in workingDirectory: URL) async throws -> String
    
    /// Send a message to the provider and get a response
    func sendMessage(_ message: String, workingDirectory: URL, sessionId: String?) async throws -> ProviderResponse
    
    /// List available sessions from the provider
    func listSessions() async throws -> [ProviderSession]
}

enum ProviderType: String, CaseIterable, Codable {
    case claudeCode = "claude-code"
    case openCode = "open-code"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .openCode: return "Open Code"
        case .custom: return "Custom"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .claudeCode: return "terminal"
        case .openCode: return "terminal.fill"
        case .custom: return "gearshape"
        }
    }
}

enum ProviderFeature: String, CaseIterable, Codable {
    case fileOperations = "file-operations"
    case gitIntegration = "git-integration"
    case webSearch = "web-search"
    case codeExecution = "code-execution"
    case imageAnalysis = "image-analysis"
    case multiModal = "multi-modal"
    case streaming = "streaming"
    
    var displayName: String {
        switch self {
        case .fileOperations: return "File Operations"
        case .gitIntegration: return "Git Integration"
        case .webSearch: return "Web Search"
        case .codeExecution: return "Code Execution"
        case .imageAnalysis: return "Image Analysis"
        case .multiModal: return "Multi-Modal"
        case .streaming: return "Streaming"
        }
    }
}

struct ProviderResponse: Codable {
    let content: String
    let sessionId: String?
    let metadata: [String: Any]?
    
    init(content: String, sessionId: String? = nil, metadata: [String: Any]? = nil) {
        self.content = content
        self.sessionId = sessionId
        self.metadata = metadata
    }
    
    // Custom coding because [String: Any] doesn't conform to Codable
    enum CodingKeys: String, CodingKey {
        case content, sessionId, metadata
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        // Skip metadata for now as it's complex to encode [String: Any]
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        metadata = nil // Skip metadata for now
    }
}

struct ProviderSession: Codable, Identifiable {
    let id: String
    let name: String
    let lastUsed: Date
    let messageCount: Int
    
    init(id: String, name: String, lastUsed: Date, messageCount: Int) {
        self.id = id
        self.name = name
        self.lastUsed = lastUsed
        self.messageCount = messageCount
    }
}

struct ProviderMessage: Codable {
    let type: MessageType
    let content: String
    let timestamp: Date
    let metadata: MessageMetadata?
    
    init(type: MessageType, content: String, metadata: MessageMetadata? = nil) {
        self.type = type
        self.content = content
        self.timestamp = Date()
        self.metadata = metadata
    }
}

enum MessageType: String, CaseIterable, Codable {
    case response = "response"
    case status = "status"
    case error = "error"
    case fileOperation = "file-operation"
    case gitOperation = "git-operation"
    case toolCall = "tool-call"
    
    var displayName: String {
        switch self {
        case .response: return "Response"
        case .status: return "Status"
        case .error: return "Error"
        case .fileOperation: return "File Operation"
        case .gitOperation: return "Git Operation"
        case .toolCall: return "Tool Call"
        }
    }
}