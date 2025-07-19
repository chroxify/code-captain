import Foundation
import Combine

class SessionService: ObservableObject {
    @Published var sessions: [Session] = []
    
    private let projectService: ProjectService
    private let providerService: ProviderService
    private var cancellables = Set<AnyCancellable>()
    private let instanceId = UUID()
    private let logger = Logger.shared
    
    init(projectService: ProjectService) {
        self.projectService = projectService
        self.providerService = ProviderService()
        logger.debug("SessionService instance created with ID: \(instanceId)", category: .session)
        loadSessions()
    }
    
    // MARK: - Session Management
    
    func createSession(for project: Project, name: String) async throws -> Session {
        // Create branch for the session
        let branchName = try await projectService.createBranch(name: name, for: project)
        
        // Create session
        let session = Session(projectId: project.id, name: name, branchName: branchName, priority: .medium, description: "", tags: [])
        
        // Add to sessions list on main thread
        await MainActor.run {
            sessions.append(session)
            saveSessions()
        }
        
        // Update project with new session
        var updatedProject = project
        updatedProject.sessions.append(session)
        await projectService.updateProject(updatedProject)
        
        // Initialize Claude Code session (it's interactive by nature)
        try await initializeSession(session)
        
        return session
    }
    
    func initializeSession(_ session: Session) async throws {
        guard session.state == .idle else {
            throw SessionError.invalidStateTransition
        }
        
        // Get project for session
        guard let project = await getProject(for: session) else {
            throw SessionError.projectNotFound
        }
        
        var updatedSession = session
        
        do {
            // Create provider session if needed
            if session.providerSessionId == nil {
                let sessionId = try await providerService.createSession(using: project.providerType, in: project.gitWorktreePath)
                updatedSession.setProviderSessionId(sessionId)
                await updateSession(updatedSession)
            }
            
            logger.debug("SessionService(\(instanceId)) initialized session \(session.id) with provider session ID: \(session.providerSessionId ?? "none")", category: .session)
            
        } catch {
            updatedSession.updateState(.error)
            await updateSession(updatedSession)
            throw error
        }
    }
    
    
    
    
    func sendMessage(_ content: String, to session: Session) async throws {
        guard session.canSendMessage else {
            logger.warning("Cannot send message - session cannot receive messages. State: \(session.state)", category: .session)
            throw SessionError.sessionNotActive
        }
        
        // Update session to processing state
        var updatedSession = session
        updatedSession.updateState(.processing)
        await updateSession(updatedSession)
        
        logger.debug("SessionService(\(instanceId)) sending message to session \(session.id): \(content)", category: .session)
        
        // Create user message
        let userMessage = Message(sessionId: session.id, content: content, role: .user)
        
        // Add message to session
        updatedSession.addMessage(userMessage)
        await updateSession(updatedSession)
        
        logger.debug("User message added to session", category: .session)
        
        // Get project for working directory
        guard let project = await getProject(for: session) else {
            throw SessionError.projectNotFound
        }
        
        do {
            // Send message to provider and get response
            let response = try await providerService.sendMessage(
                content,
                using: project.providerType,
                workingDirectory: project.gitWorktreePath,
                sessionId: session.providerSessionId
            )
            
            // Process response messages
            if let sdkMessages = response.messages, !sdkMessages.isEmpty {
                // Create rich messages from SDK messages
                for sdkMessage in sdkMessages {
                    let message = Message(from: sdkMessage, sessionId: session.id)
                    updatedSession.addMessage(message)
                }
            } else {
                // Fallback to legacy single message
                let assistantMessage = Message(
                    sessionId: session.id,
                    content: response.content,
                    role: .assistant,
                    metadata: response.metadata.map { metadata in
                        MessageMetadata(
                            filesChanged: metadata["filesChanged"] as? [String],
                            gitOperations: metadata["gitOperations"] as? [String],
                            toolsUsed: metadata["toolsUsed"] as? [String]
                        )
                    }
                )
                updatedSession.addMessage(assistantMessage)
            }
            
            // Extract todos from messages (provider-agnostic)
            await extractTodosFromMessages(for: &updatedSession)
            
            // Always update session ID from response (this is critical for session continuity)
            if let newSessionId = response.sessionId, !newSessionId.isEmpty {
                let currentSessionId = updatedSession.providerSessionId
                
                // Always update the session ID to ensure proper session evolution
                if currentSessionId != newSessionId {
                    logger.debug("Updating session ID from \(currentSessionId ?? "nil") to \(newSessionId)", category: .session)
                    updatedSession.setProviderSessionId(newSessionId)
                }
            }
            
            // Update session to ready for review state
            updatedSession.updateState(.readyForReview)
            await updateSession(updatedSession)
            
            logger.debug("Message sent to Claude Code successfully", category: .session)
            
        } catch {
            logger.error("Error sending message to Claude Code: \(error)", category: .session)
            
            // If the error is about session not found, clear the session ID and try to create a new one
            if error.localizedDescription.contains("No conversation found") {
                
                logger.debug("Session ID invalid, clearing and creating new session", category: .session)
                updatedSession.setProviderSessionId(nil as String?)
                await updateSession(updatedSession)
                
                // Try to create a new session
                do {
                    let newSessionId = try await providerService.createSession(using: project.providerType, in: project.gitWorktreePath)
                    updatedSession.setProviderSessionId(newSessionId)
                    await updateSession(updatedSession)
                    
                    // Retry sending the message with new session
                    return try await sendMessage(content, to: updatedSession)
                } catch {
                    logger.error("Failed to create new session: \(error)", category: .session)
                    throw error
                }
            }
            
            throw error
        }
    }
    
    func deleteSession(_ session: Session) async throws {
        // Sessions are always conceptually active, no need to stop
        
        // Remove from sessions list on main thread
        await MainActor.run {
            sessions.removeAll { $0.id == session.id }
            saveSessions()
        }
        
        // Remove from project
        if let project = await getProject(for: session) {
            var updatedProject = project
            updatedProject.sessions.removeAll { $0.id == session.id }
            await projectService.updateProject(updatedProject)
        }
        
        // Note: Claude Code sessions are managed externally
    }
    
    func queueSession(_ session: Session) async throws {
        guard session.canQueue else {
            throw SessionError.invalidStateTransition
        }
        
        // Update session state on main thread
        var updatedSession = session
        updatedSession.updateState(.queued)
        await updateSession(updatedSession)
        
        logger.debug("SessionService(\(instanceId)) queued session \(session.id)", category: .session)
    }
    
    func archiveSession(_ session: Session) async throws {
        guard session.canArchive else {
            throw SessionError.invalidStateTransition
        }
        
        // Update session state on main thread
        var updatedSession = session
        updatedSession.updateState(.archived)
        await updateSession(updatedSession)
        
        logger.debug("SessionService(\(instanceId)) archived session \(session.id)", category: .session)
    }
    
    func unarchiveSession(_ session: Session) async throws {
        guard session.state == .archived else {
            throw SessionError.invalidStateTransition
        }
        
        // Update session state on main thread
        var updatedSession = session
        updatedSession.updateState(.idle)
        await updateSession(updatedSession)
        
        logger.debug("SessionService(\(instanceId)) unarchived session \(session.id)", category: .session)
    }
    
    func updateSessionPriority(_ session: Session, priority: SessionPriority) async throws {
        // Update session priority on main thread
        var updatedSession = session
        updatedSession.updatePriority(priority)
        await updateSession(updatedSession)
        
        logger.debug("SessionService(\(instanceId)) updated session \(session.id) priority to \(priority.displayName)", category: .session)
    }
    
    // MARK: - Message Monitoring
    // Note: Message monitoring is now handled synchronously in sendMessage
    // since we're using Claude Code CLI in print mode
    
    func sendMessageStream(_ content: String, to session: Session) -> AsyncStream<Message> {
        guard session.canSendMessage else {
            return AsyncStream { continuation in
                logger.warning("Cannot send message - session cannot receive messages. State: \(session.state)", category: .session)
                continuation.finish()
            }
        }
        
        logger.debug("SessionService(\(instanceId)) sending streaming message to session \(session.id): \(content)", category: .session)
        
        return AsyncStream { continuation in
            Task {
                // Create user message first
                let userMessage = Message(sessionId: session.id, content: content, role: .user)
                
                // Add user message to session and update state to processing
                var updatedSession = session
                updatedSession.addMessage(userMessage)
                updatedSession.updateState(.processing)
                await updateSession(updatedSession)
                
                // Yield the user message immediately
                continuation.yield(userMessage)
                
                // Get project for working directory
                guard let project = await getProject(for: session) else {
                    logger.warning("Project not found for session", category: .session)
                    continuation.finish()
                    return
                }
                
                // Create stream for Claude Code responses
                if let providerSessionId = session.providerSessionId {
                    logger.debug("SessionService sending message with existing provider session ID: \(providerSessionId)", category: .session)
                } else {
                    logger.debug("SessionService sending message without provider session ID (will start new session)", category: .session)
                }
                
                let messageStream = providerService.sendMessageStream(
                    content,
                    using: project.providerType,
                    workingDirectory: project.gitWorktreePath,
                    sessionId: session.providerSessionId
                )
                
                // Process each streaming message
                for await sdkMessage in messageStream {
                    logger.debug("Received streaming SDK message: \(sdkMessage.id)", category: .communication)
                    
                    var message = Message(from: sdkMessage, sessionId: session.id)
                    
                    // Process tool statuses for this specific message
                    message.processToolStatuses()
                    
                    updatedSession.addMessage(message)
                    
                    // Always update session ID from response (this is critical for session continuity)
                    let newSessionId = sdkMessage.sessionId
                    if !newSessionId.isEmpty {
                        let currentSessionId = updatedSession.providerSessionId
                        
                        // Always update the session ID to ensure proper session evolution
                        if currentSessionId != newSessionId {
                            logger.debug("Updating session ID from \(currentSessionId ?? "nil") to \(newSessionId)", category: .session)
                            updatedSession.setProviderSessionId(newSessionId)
                        }
                    }
                    
                    // Extract todos from the current streaming message immediately for real-time updates
                    await extractTodosFromStreamingMessage(sdkMessage, for: &updatedSession)
                    
                    await updateSession(updatedSession)
                    
                    // Yield the message immediately
                    continuation.yield(message)
                }
                
                // Update session to ready for review state when streaming completes
                updatedSession.updateState(.readyForReview)
                await updateSession(updatedSession)
                
                logger.debug("Streaming completed for session \(session.id)", category: .session)
                continuation.finish()
            }
        }
    }
    
    // MARK: - Provider Methods
    
    func getProviderVersion(for type: ProviderType) async -> String? {
        return await providerService.getProviderVersion(for: type)
    }
    
    // MARK: - Helper Methods
    
    func updateSession(_ session: Session) async {
        await MainActor.run {
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
                saveSessions()
            }
        }
    }
    
    private func getProject(for session: Session) async -> Project? {
        return await MainActor.run { projectService.projects.first { $0.id == session.projectId } }
    }
    
    func getSession(by id: UUID) -> Session? {
        return sessions.first { $0.id == id }
    }
    
    func getActiveSessions() -> [Session] {
        return sessions.filter { $0.isActive }
    }
    
    func getSessionsForProject(_ project: Project) -> [Session] {
        return sessions.filter { $0.projectId == project.id }
    }
    
    // MARK: - Todo Management
    
    private func extractTodosFromStreamingMessage(_ sdkMessage: SDKMessage, for session: inout Session) async {
        // Extract todos from the current streaming message immediately for real-time updates
        switch sdkMessage {
        case .assistant(let assistantMessage):
            // Look for tool_use blocks in assistant messages
            for contentBlock in assistantMessage.message.content {
                if case .toolUse(let toolUse) = contentBlock,
                   toolUse.name == "TodoWrite" {
                    // Extract todos from TodoWrite tool call
                    if let newTodos = extractTodosFromToolUse(toolUse) {
                        // Merge with existing todos to preserve completion dates
                        let updatedTodos = mergeTodosPreservingCompletionDates(newTodos: newTodos, existingTodos: session.todos)
                        
                        // Update session with merged todos immediately
                        session.updateTodos(updatedTodos)
                        
                        if newTodos.isEmpty {
                            logger.debug("Cleared all todos from streaming message: \(sdkMessage.id)", category: .session)
                        } else {
                            logger.debug("Extracted \(newTodos.count) todos from streaming message: \(sdkMessage.id)", category: .session)
                        }
                    }
                }
            }
        default:
            // Only assistant messages contain tool_use blocks
            break
        }
    }
    
    private func extractTodosFromMessages(for session: inout Session) async {
        // Extract todos from all messages in the session
        var allTodos: [SessionTodo] = []
        
        for message in session.messages {
            if let sdkMessage = message.sdkMessage {
                switch sdkMessage {
                case .assistant(let assistantMessage):
                    // Look for tool_use blocks in assistant messages
                    for contentBlock in assistantMessage.message.content {
                        if case .toolUse(let toolUse) = contentBlock,
                           toolUse.name == "TodoWrite" {
                            // Extract todos from TodoWrite tool call
                            if let todos = extractTodosFromToolUse(toolUse) {
                                allTodos.append(contentsOf: todos)
                            }
                        }
                    }
                default:
                    // Only assistant messages contain tool_use blocks
                    break
                }
            }
        }
        
        // Update session with extracted todos
        if !allTodos.isEmpty {
            session.updateTodos(allTodos)
            logger.debug("Extracted \(allTodos.count) todos from session messages", category: .session)
        }
    }
    
    private func extractTodosFromToolUse(_ toolUse: ToolUseBlock) -> [SessionTodo]? {
        // Parse the TodoWrite tool input to extract todos
        guard let todosArray = toolUse.input["todos"]?.value as? [[String: Any]] else {
            return nil
        }
        
        var todos: [SessionTodo] = []
        
        for todoDict in todosArray {
            guard let id = todoDict["id"] as? String,
                  let content = todoDict["content"] as? String,
                  let statusString = todoDict["status"] as? String,
                  let priorityString = todoDict["priority"] as? String,
                  let status = TodoStatus(rawValue: statusString),
                  let priority = TodoPriority(rawValue: priorityString) else {
                continue
            }
            
            let todo = SessionTodo(id: id, content: content, status: status, priority: priority)
            todos.append(todo)
        }
        
        // Always return the array (even if empty) to allow for todo clearing
        // An empty array means "clear all todos" which is different from nil (invalid/no TodoWrite call)
        return todos
    }
    
    private func mergeTodosPreservingCompletionDates(newTodos: [SessionTodo], existingTodos: [SessionTodo]) -> [SessionTodo] {
        // The new TodoWrite call represents the complete, authoritative list of todos
        // Any todo not in this list should be deleted (which happens automatically by only returning newTodos)
        // But we need to preserve completion dates for todos that remain
        
        // Create a map of existing todos by ID for efficient lookup
        let existingTodoMap = Dictionary(uniqueKeysWithValues: existingTodos.map { ($0.id, $0) })
        
        var mergedTodos: [SessionTodo] = []
        
        // Process each todo in the new authoritative list
        for newTodo in newTodos {
            var finalTodo = newTodo
            
            // Check if this todo existed before
            if let existingTodo = existingTodoMap[newTodo.id] {
                // If the todo was previously completed and is still completed, preserve the completion date
                if existingTodo.status == .completed && newTodo.status == .completed {
                    finalTodo = SessionTodo(
                        id: newTodo.id,
                        content: newTodo.content,
                        status: newTodo.status,
                        priority: newTodo.priority,
                        completedAt: existingTodo.completedAt
                    )
                }
                // If the todo is newly completed, set completion date to now
                else if existingTodo.status != .completed && newTodo.status == .completed {
                    finalTodo = SessionTodo(
                        id: newTodo.id,
                        content: newTodo.content,
                        status: newTodo.status,
                        priority: newTodo.priority,
                        completedAt: Date()
                    )
                }
                // If the todo was completed but is now uncompleted, clear completion date
                else if existingTodo.status == .completed && newTodo.status != .completed {
                    finalTodo = SessionTodo(
                        id: newTodo.id,
                        content: newTodo.content,
                        status: newTodo.status,
                        priority: newTodo.priority,
                        completedAt: nil
                    )
                }
                // For any other status changes, preserve the existing completion date if any
                else {
                    finalTodo = SessionTodo(
                        id: newTodo.id,
                        content: newTodo.content,
                        status: newTodo.status,
                        priority: newTodo.priority,
                        completedAt: existingTodo.completedAt
                    )
                }
            }
            // If this is a completely new todo that's already completed, set completion date
            else if newTodo.status == .completed {
                finalTodo = SessionTodo(
                    id: newTodo.id,
                    content: newTodo.content,
                    status: newTodo.status,
                    priority: newTodo.priority,
                    completedAt: Date()
                )
            }
            
            mergedTodos.append(finalTodo)
        }
        
        // Log deletion information for debugging
        let deletedTodos = existingTodos.filter { existingTodo in
            !newTodos.contains { $0.id == existingTodo.id }
        }
        
        if !deletedTodos.isEmpty {
            if newTodos.isEmpty {
                logger.debug("Clearing all \(deletedTodos.count) todos: \(deletedTodos.map { $0.content })", category: .session)
            } else {
                logger.debug("Deleting \(deletedTodos.count) todos: \(deletedTodos.map { $0.content })", category: .session)
            }
        }
        
        // Return only the todos that are in the new authoritative list
        // This effectively deletes any todos not present in newTodos
        return mergedTodos
    }
    
    // MARK: - Persistence
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "CodeCaptain.Sessions")
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "CodeCaptain.Sessions"),
           let decoded = try? JSONDecoder().decode([Session].self, from: data) {
            sessions = decoded
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() async {
        // Sessions are conceptually always active, no need to stop them
        // Just clean up any resources
    }
}

// MARK: - Errors

enum SessionError: LocalizedError {
    case invalidStateTransition
    case projectNotFound
    case sessionNotActive
    case providerNotAvailable
    case communicationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidStateTransition:
            return "Invalid session state transition."
        case .projectNotFound:
            return "Project not found for session."
        case .sessionNotActive:
            return "Session is not active."
        case .providerNotAvailable:
            return "Provider is not available."
        case .communicationFailed:
            return "Communication with provider failed."
        }
    }
}