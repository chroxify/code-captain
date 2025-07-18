import Foundation

struct Session: Identifiable, Codable, Hashable {
    let id: UUID
    let projectId: UUID
    let name: String
    let branchName: String
    let createdAt: Date
    var lastActiveAt: Date
    var state: SessionState
    var messages: [Message]
    var providerSessionId: String?
    
    init(projectId: UUID, name: String, branchName: String? = nil) {
        self.id = UUID()
        self.projectId = projectId
        self.name = name
        self.branchName = branchName ?? "session-\(UUID().uuidString.prefix(8))-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        self.createdAt = Date()
        self.lastActiveAt = Date()
        self.state = .idle
        self.messages = []
        self.providerSessionId = nil
    }
    
    var displayName: String {
        name.isEmpty ? "Session \(id.uuidString.prefix(8))" : name
    }
    
    var isActive: Bool {
        state == .active
    }
    
    var canStart: Bool {
        state == .idle || state == .paused
    }
    
    var canStop: Bool {
        state == .active || state == .starting
    }
    
    mutating func updateState(_ newState: SessionState) {
        self.state = newState
        self.lastActiveAt = Date()
    }
    
    mutating func addMessage(_ message: Message) {
        messages.append(message)
        self.lastActiveAt = Date()
    }
    
    mutating func setProviderSessionId(_ sessionId: String?) {
        self.providerSessionId = sessionId
        self.lastActiveAt = Date()
    }
    
    var hasProviderSession: Bool {
        return providerSessionId != nil
    }
}

enum SessionState: String, CaseIterable, Codable {
    case idle = "idle"
    case starting = "starting"
    case active = "active"
    case paused = "paused"
    case stopping = "stopping"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .starting: return "Starting"
        case .active: return "Active"
        case .paused: return "Paused"
        case .stopping: return "Stopping"
        case .error: return "Error"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .idle: return "circle"
        case .starting: return "arrow.clockwise"
        case .active: return "circle.fill"
        case .paused: return "pause.circle"
        case .stopping: return "stop.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
}

extension Session {
    static let mock = Session(
        projectId: UUID(),
        name: "Frontend Development",
        branchName: "session-frontend"
    )
}