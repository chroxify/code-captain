import Foundation

enum SessionPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "arrow.up.circle"
        case .urgent: return "exclamationmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "yellow"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}

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
    
    // Session metadata
    var priority: SessionPriority
    var tags: [String]
    var description: String
    var estimatedDuration: TimeInterval?
    var actualDuration: TimeInterval?
    var startedAt: Date?
    var completedAt: Date?
    var parentSessionId: UUID?
    var dependentSessionIds: [UUID]
    
    init(projectId: UUID, name: String, branchName: String? = nil, priority: SessionPriority = .medium, description: String = "", tags: [String] = []) {
        self.id = UUID()
        self.projectId = projectId
        self.name = name
        self.branchName = branchName ?? "session-\(UUID().uuidString.prefix(8))-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        self.createdAt = Date()
        self.lastActiveAt = Date()
        self.state = .idle
        self.messages = []
        self.providerSessionId = nil
        
        // Initialize metadata with defaults
        self.priority = priority
        self.tags = tags
        self.description = description
        self.estimatedDuration = nil
        self.actualDuration = nil
        self.startedAt = nil
        self.completedAt = nil
        self.parentSessionId = nil
        self.dependentSessionIds = []
    }
    
    var displayName: String {
        name.isEmpty ? "Session \(id.uuidString.prefix(8))" : name
    }
    
    var isActive: Bool {
        state == .processing || state == .waitingForInput
    }
    
    var canSendMessage: Bool {
        state == .idle || state == .readyForReview || state == .waitingForInput
    }
    
    var canQueue: Bool {
        state == .idle || state == .readyForReview
    }
    
    var canArchive: Bool {
        state == .idle || state == .readyForReview || state == .error || state == .failed
    }
    
    mutating func updateState(_ newState: SessionState) {
        // Track timing metadata
        if newState == .processing && self.state != .processing {
            self.startedAt = Date()
        }
        
        if (newState == .archived || newState == .failed || newState == .readyForReview) && self.state == .processing {
            self.completedAt = Date()
            if let startTime = self.startedAt {
                self.actualDuration = Date().timeIntervalSince(startTime)
            }
        }
        
        self.state = newState
        self.lastActiveAt = Date()
    }
    
    mutating func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }
    
    mutating func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    mutating func updatePriority(_ newPriority: SessionPriority) {
        self.priority = newPriority
        self.lastActiveAt = Date()
    }
    
    mutating func setEstimatedDuration(_ duration: TimeInterval) {
        self.estimatedDuration = duration
    }
    
    var formattedDuration: String {
        guard let duration = actualDuration ?? estimatedDuration else {
            return "Unknown"
        }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
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
    case processing = "processing"
    case waitingForInput = "waitingForInput"
    case readyForReview = "readyForReview"
    case error = "error"
    case queued = "queued"
    case archived = "archived"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .processing: return "Processing"
        case .waitingForInput: return "Waiting for Input"
        case .readyForReview: return "Ready for Review"
        case .error: return "Error"
        case .queued: return "Queued"
        case .archived: return "Archived"
        case .failed: return "Failed"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .idle: return "circle"
        case .processing: return "arrow.clockwise"
        case .waitingForInput: return "hand.raised.circle"
        case .readyForReview: return "checkmark.circle"
        case .error: return "exclamationmark.circle"
        case .queued: return "clock.badge.plus"
        case .archived: return "archivebox"
        case .failed: return "xmark.circle"
        }
    }
    
    var isProcessing: Bool {
        return self == .processing
    }
    
    var isWaitingForAction: Bool {
        return self == .waitingForInput || self == .readyForReview
    }
    
    var isCompleted: Bool {
        return self == .readyForReview
    }
}

extension Session {
    static let mock = Session(
        projectId: UUID(),
        name: "Frontend Development",
        branchName: "session-frontend",
        priority: .medium,
        description: "Mock session for testing",
        tags: ["frontend", "development"]
    )
}
