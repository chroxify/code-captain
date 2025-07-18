import Foundation
import Combine

class SessionService: ObservableObject {
    @Published var sessions: [Session] = []
    
    private let projectService: ProjectService
    private let providerService: ProviderService
    private var cancellables = Set<AnyCancellable>()
    private let instanceId = UUID()
    
    init(projectService: ProjectService) {
        self.projectService = projectService
        self.providerService = ProviderService()
        print("DEBUG: SessionService instance created with ID: \(instanceId)")
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
            
            print("DEBUG: SessionService(\(instanceId)) initialized session \(session.id) with provider session ID: \(session.providerSessionId ?? "none")")
            
        } catch {
            updatedSession.updateState(.error)
            await updateSession(updatedSession)
            throw error
        }
    }
    
    
    
    
    func sendMessage(_ content: String, to session: Session) async throws {
        guard session.canSendMessage else {
            print("DEBUG: Cannot send message - session cannot receive messages. State: \(session.state)")
            throw SessionError.sessionNotActive
        }
        
        // Update session to processing state
        var updatedSession = session
        updatedSession.updateState(.processing)
        await updateSession(updatedSession)
        
        print("DEBUG: SessionService(\(instanceId)) sending message to session \(session.id): \(content)")
        
        // Create user message
        let userMessage = Message(sessionId: session.id, content: content, role: .user)
        
        // Add message to session
        updatedSession.addMessage(userMessage)
        await updateSession(updatedSession)
        
        print("DEBUG: User message added to session")
        
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
            
            // Always update session ID from response (this is critical for session continuity)
            if let newSessionId = response.sessionId, !newSessionId.isEmpty {
                let currentSessionId = updatedSession.providerSessionId
                
                // Always update the session ID to ensure proper session evolution
                if currentSessionId != newSessionId {
                    print("DEBUG: Updating session ID from \(currentSessionId ?? "nil") to \(newSessionId)")
                    updatedSession.setProviderSessionId(newSessionId)
                }
            }
            
            // Update session to ready for review state
            updatedSession.updateState(.readyForReview)
            await updateSession(updatedSession)
            
            print("DEBUG: Message sent to Claude Code successfully")
            
        } catch {
            print("DEBUG: Error sending message to Claude Code: \(error)")
            
            // If the error is about session not found, clear the session ID and try to create a new one
            if error.localizedDescription.contains("No conversation found") {
                
                print("DEBUG: Session ID invalid, clearing and creating new session")
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
                    print("DEBUG: Failed to create new session: \(error)")
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
        
        print("DEBUG: SessionService(\(instanceId)) queued session \(session.id)")
    }
    
    func archiveSession(_ session: Session) async throws {
        guard session.canArchive else {
            throw SessionError.invalidStateTransition
        }
        
        // Update session state on main thread
        var updatedSession = session
        updatedSession.updateState(.archived)
        await updateSession(updatedSession)
        
        print("DEBUG: SessionService(\(instanceId)) archived session \(session.id)")
    }
    
    func unarchiveSession(_ session: Session) async throws {
        guard session.state == .archived else {
            throw SessionError.invalidStateTransition
        }
        
        // Update session state on main thread
        var updatedSession = session
        updatedSession.updateState(.idle)
        await updateSession(updatedSession)
        
        print("DEBUG: SessionService(\(instanceId)) unarchived session \(session.id)")
    }
    
    func updateSessionPriority(_ session: Session, priority: SessionPriority) async throws {
        // Update session priority on main thread
        var updatedSession = session
        updatedSession.updatePriority(priority)
        await updateSession(updatedSession)
        
        print("DEBUG: SessionService(\(instanceId)) updated session \(session.id) priority to \(priority.displayName)")
    }
    
    // MARK: - Message Monitoring
    // Note: Message monitoring is now handled synchronously in sendMessage
    // since we're using Claude Code CLI in print mode
    
    func sendMessageStream(_ content: String, to session: Session) -> AsyncStream<Message> {
        guard session.canSendMessage else {
            return AsyncStream { continuation in
                print("DEBUG: Cannot send message - session cannot receive messages. State: \(session.state)")
                continuation.finish()
            }
        }
        
        print("DEBUG: SessionService(\(instanceId)) sending streaming message to session \(session.id): \(content)")
        
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
                    print("DEBUG: Project not found for session")
                    continuation.finish()
                    return
                }
                
                // Create stream for Claude Code responses
                if let providerSessionId = session.providerSessionId {
                    print("DEBUG: SessionService sending message with existing provider session ID: \(providerSessionId)")
                } else {
                    print("DEBUG: SessionService sending message without provider session ID (will start new session)")
                }
                
                let messageStream = providerService.sendMessageStream(
                    content,
                    using: project.providerType,
                    workingDirectory: project.gitWorktreePath,
                    sessionId: session.providerSessionId
                )
                
                // Process each streaming message
                for await sdkMessage in messageStream {
                    print("DEBUG: Received streaming SDK message: \(sdkMessage.id)")
                    
                    let message = Message(from: sdkMessage, sessionId: session.id)
                    updatedSession.addMessage(message)
                    
                    // Always update session ID from response (this is critical for session continuity)
                    let newSessionId = sdkMessage.sessionId
                    if !newSessionId.isEmpty {
                        let currentSessionId = updatedSession.providerSessionId
                        
                        // Always update the session ID to ensure proper session evolution
                        if currentSessionId != newSessionId {
                            print("DEBUG: Updating session ID from \(currentSessionId ?? "nil") to \(newSessionId)")
                            updatedSession.setProviderSessionId(newSessionId)
                        }
                    }
                    
                    await updateSession(updatedSession)
                    
                    // Yield the message immediately
                    continuation.yield(message)
                }
                
                // Update session to ready for review state when streaming completes
                updatedSession.updateState(.readyForReview)
                await updateSession(updatedSession)
                
                print("DEBUG: Streaming completed for session \(session.id)")
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