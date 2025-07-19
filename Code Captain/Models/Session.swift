import Foundation

struct SessionTodo: Identifiable, Codable, Hashable {
    let id: String
    let content: String
    let status: TodoStatus
    let priority: TodoPriority
    let createdAt: Date
    var completedAt: Date?
    
    init(id: String, content: String, status: TodoStatus, priority: TodoPriority, completedAt: Date? = nil) {
        self.id = id
        self.content = content
        self.status = status
        self.priority = priority
        self.createdAt = Date()
        self.completedAt = completedAt
    }
}

enum TodoStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .pending: return "circle"
        case .inProgress: return "clock"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

enum TodoPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "arrow.up.circle"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "secondary"
        case .high: return "orange"
        }
    }
}

enum SessionPriority: String, CaseIterable, Codable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .none: return ""
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "arrow.up.circle"
        case .urgent: return "exclamationmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .none: return "secondary"
        case .low: return "blue"
        case .medium: return "yellow"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
    
    var rawValue: String {
        switch self {
        case .none: return "none"
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .urgent: return "urgent"
        }
    }
    
    var priorityValue: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .urgent: return 4
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
    
    // Todo management
    var todos: [SessionTodo]
    
    init(projectId: UUID, name: String, branchName: String? = nil, priority: SessionPriority = .none, description: String = "", tags: [String] = []) {
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
        self.todos = []
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
        // STEP-BY-STEP STREAMING: Complete any processing steps from previous messages before adding new message
        completeProcessingStepsFromPreviousMessages()
        
        messages.append(message)
        self.lastActiveAt = Date()
        
        // After adding the message, process cross-message tool completions
        processToolCompletions()
    }
    
    /// Complete any processing steps from previous messages when a new message/step arrives
    /// This implements the streaming lifecycle: any new stream/step completes the previous processing step
    /// IMPORTANT: Only completes thinking blocks and other non-tool steps, NOT tool_use blocks waiting for results
    private mutating func completeProcessingStepsFromPreviousMessages() {
        for messageIndex in messages.indices {
            var message = messages[messageIndex]
            var hasChanges = false
            
            // Complete any processing tool statuses in this message
            for statusIndex in message.toolStatuses.indices {
                let toolStatus = message.toolStatuses[statusIndex]
                
                if toolStatus.isProcessing {
                    // Only complete thinking blocks and non-tool processing steps
                    // tool_use blocks should only be completed by their corresponding tool_result
                    let shouldComplete = toolStatus.toolType == .task // thinking blocks
                    
                    if shouldComplete {
                        // Complete this processing step
                        let completedStatus = ToolStatus(
                            id: toolStatus.id,
                            toolType: toolStatus.toolType,
                            state: .completed(duration: Date().timeIntervalSince(toolStatus.startTime)),
                            preview: toolStatus.preview,
                            fullContent: toolStatus.fullContent,
                            startTime: toolStatus.startTime,
                            endTime: Date()
                        )
                        
                        message.toolStatuses[statusIndex] = completedStatus
                        hasChanges = true
                    }
                }
            }
            
            if hasChanges {
                messages[messageIndex] = message
            }
        }
    }
    
    /// Process tool completions across messages in the session
    /// This handles the case where tool_use blocks in assistant messages need to be completed
    /// by tool_result blocks in subsequent user messages
    private mutating func processToolCompletions() {
        // Find all pending tool_use blocks in assistant messages
        var pendingTools: [(messageIndex: Int, toolStatus: ToolStatus)] = []
        
        for (messageIndex, message) in messages.enumerated() {
            for toolStatus in message.toolStatuses {
                if toolStatus.isProcessing {
                    pendingTools.append((messageIndex: messageIndex, toolStatus: toolStatus))
                }
            }
        }
        
        // Find tool_result blocks in user messages to complete pending tools
        for (messageIndex, message) in messages.enumerated() {
            if let sdkMessage = message.sdkMessage,
               case .user(let userMessage) = sdkMessage,
               case .blocks(let blocks) = userMessage.message.content {
                
                for block in blocks {
                    if block.type == "tool_result",
                       let toolUseId = block.tool_use_id {
                        
                        // Find the corresponding pending tool
                        for (pendingIndex, pendingTool) in pendingTools.enumerated() {
                            let pendingToolStatus = pendingTool.toolStatus
                            
                            // Match by tool_use_id (extract from the unique ID)
                            if pendingToolStatus.id.hasSuffix("tool-\(toolUseId)") {
                                // Create completed status
                                let completedStatus = createCompletedToolStatus(
                                    from: pendingToolStatus,
                                    result: block.content,
                                    isError: block.is_error ?? false
                                )
                                
                                // Update the tool status in the original message
                                let originalMessageIndex = pendingTool.messageIndex
                                if let statusIndex = messages[originalMessageIndex].toolStatuses.firstIndex(where: { $0.id == pendingToolStatus.id }) {
                                    messages[originalMessageIndex].toolStatuses[statusIndex] = completedStatus
                                }
                                
                                // Remove from pending list
                                pendingTools.remove(at: pendingIndex)
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Create a completed tool status from a processing tool status
    private func createCompletedToolStatus(from activeStatus: ToolStatus, result: String?, isError: Bool) -> ToolStatus {
        let endTime = Date()
        let duration = endTime.timeIntervalSince(activeStatus.startTime)
        
        let state: ToolStatusState = isError ? 
            .error(message: result ?? "Unknown error") :
            .completed(duration: duration)
        
        return ToolStatus(
            id: activeStatus.id,
            toolType: activeStatus.toolType,
            state: state,
            preview: activeStatus.preview,
            fullContent: result ?? activeStatus.fullContent,
            startTime: activeStatus.startTime,
            endTime: endTime
        )
    }
    
    mutating func setProviderSessionId(_ sessionId: String?) {
        self.providerSessionId = sessionId
        self.lastActiveAt = Date()
    }
    
    var hasProviderSession: Bool {
        return providerSessionId != nil
    }
    
    // MARK: - Todo Management
    
    mutating func updateTodos(_ newTodos: [SessionTodo]) {
        self.todos = newTodos
        self.lastActiveAt = Date()
    }
    
    mutating func addTodo(_ todo: SessionTodo) {
        // Replace existing todo with same id or add new one
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index] = todo
        } else {
            todos.append(todo)
        }
        self.lastActiveAt = Date()
    }
    
    mutating func removeTodo(withId id: String) {
        todos.removeAll { $0.id == id }
        self.lastActiveAt = Date()
    }
    
    
    var completedTodosCount: Int {
        todos.filter { $0.status == .completed }.count
    }
    
    var totalTodosCount: Int {
        todos.count
    }
    
    var todoProgress: Double {
        guard totalTodosCount > 0 else { return 0 }
        return Double(completedTodosCount) / Double(totalTodosCount)
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
