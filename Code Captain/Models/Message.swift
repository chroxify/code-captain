import Foundation

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let sessionId: UUID
    let content: String
    let role: MessageRole
    let timestamp: Date
    var metadata: MessageMetadata?
    
    init(sessionId: UUID, content: String, role: MessageRole, metadata: MessageMetadata? = nil) {
        self.id = UUID()
        self.sessionId = sessionId
        self.content = content
        self.role = role
        self.timestamp = Date()
        self.metadata = metadata
    }
    
    var isFromUser: Bool {
        role == .user
    }
    
    var isFromAssistant: Bool {
        role == .assistant
    }
    
    var displayContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    init(filesChanged: [String]? = nil, gitOperations: [String]? = nil, toolsUsed: [String]? = nil, processingTime: TimeInterval? = nil, errorInfo: String? = nil) {
        self.filesChanged = filesChanged
        self.gitOperations = gitOperations
        self.toolsUsed = toolsUsed
        self.processingTime = processingTime
        self.errorInfo = errorInfo
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
        content: "I'd be happy to help you fix the bug in your React component. Let me first examine the component to understand the issue. Can you show me the component code?",
        role: .assistant,
        metadata: MessageMetadata(toolsUsed: ["Read", "Analyze"])
    )
}