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
        let session = Session(projectId: project.id, name: name, branchName: branchName)
        
        // Add to sessions list on main thread
        await MainActor.run {
            sessions.append(session)
            saveSessions()
        }
        
        // Update project with new session
        var updatedProject = project
        updatedProject.sessions.append(session)
        await projectService.updateProject(updatedProject)
        
        // Auto-start Claude Code session (it's interactive by nature)
        try await startSession(session)
        
        return session
    }
    
    func startSession(_ session: Session) async throws {
        guard session.canStart else {
            throw SessionError.invalidStateTransition
        }
        
        // Update session state on main thread
        var updatedSession = session
        updatedSession.updateState(.starting)
        await updateSession(updatedSession)
        
        // Get project for session
        guard let project = await getProject(for: session) else {
            throw SessionError.projectNotFound
        }
        
        do {
            // Create or resume Claude Code session
            let sessionId: String
            if let existingSessionId = session.claudeSessionId {
                sessionId = existingSessionId
            } else {
                sessionId = try await providerService.createSession(using: project.providerType, in: project.gitWorktreePath)
                updatedSession.setClaudeSessionId(sessionId)
            }
            
            // Update session state
            updatedSession.updateState(.active)
            await updateSession(updatedSession)
            
            print("DEBUG: SessionService(\(instanceId)) started session \(session.id) with Claude session ID: \(sessionId)")
            
        } catch {
            updatedSession.updateState(.error)
            await updateSession(updatedSession)
            throw error
        }
    }
    
    func stopSession(_ session: Session) async throws {
        guard session.canStop else {
            throw SessionError.invalidStateTransition
        }
        
        // Update session state on main thread
        var updatedSession = session
        updatedSession.updateState(.stopping)
        await updateSession(updatedSession)
        
        // Claude Code sessions are stateless, so we just update the UI state
        updatedSession.updateState(.idle)
        await updateSession(updatedSession)
        
        print("DEBUG: SessionService(\(instanceId)) stopped session \(session.id)")
    }
    
    func pauseSession(_ session: Session) async throws {
        guard session.state == .active else {
            throw SessionError.invalidStateTransition
        }
        
        // Update session state on main thread
        var updatedSession = session
        updatedSession.updateState(.paused)
        await updateSession(updatedSession)
        
        // Claude Code CLI doesn't support pause/resume
        // Just update the UI state
        print("DEBUG: SessionService(\(instanceId)) paused session \(session.id)")
    }
    
    func resumeSession(_ session: Session) async throws {
        guard session.state == .paused else {
            throw SessionError.invalidStateTransition
        }
        
        // Update session state on main thread
        var updatedSession = session
        updatedSession.updateState(.active)
        await updateSession(updatedSession)
        
        // Claude Code CLI doesn't support pause/resume
        // Just update the UI state
        print("DEBUG: SessionService(\(instanceId)) resumed session \(session.id)")
    }
    
    func sendMessage(_ content: String, to session: Session) async throws {
        guard session.state == .active else {
            print("DEBUG: Cannot send message - session not active. State: \(session.state)")
            throw SessionError.sessionNotActive
        }
        
        print("DEBUG: SessionService(\(instanceId)) sending message to session \(session.id): \(content)")
        
        // Create user message
        let userMessage = Message(sessionId: session.id, content: content, role: .user)
        
        // Add message to session on main thread
        var updatedSession = session
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
                sessionId: session.claudeSessionId
            )
            
            // Create assistant message from response
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
            
            // Add assistant message to session
            updatedSession.addMessage(assistantMessage)
            
            // Update session ID if we got a new one
            if let newSessionId = response.sessionId {
                updatedSession.setClaudeSessionId(newSessionId)
            }
            
            await updateSession(updatedSession)
            
            print("DEBUG: Message sent to Claude Code successfully")
            
        } catch {
            print("DEBUG: Error sending message to Claude Code: \(error)")
            
            // If the error is about session not found, clear the session ID and try to create a new one
            if error.localizedDescription.contains("No conversation found") {
                
                print("DEBUG: Session ID invalid, clearing and creating new session")
                updatedSession.setClaudeSessionId(nil)
                await updateSession(updatedSession)
                
                // Try to create a new session
                do {
                    let newSessionId = try await providerService.createSession(using: project.providerType, in: project.gitWorktreePath)
                    updatedSession.setClaudeSessionId(newSessionId)
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
        // Stop session if active
        if session.isActive {
            try await stopSession(session)
        }
        
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
    
    // MARK: - Message Monitoring
    // Note: Message monitoring is now handled synchronously in sendMessage
    // since we're using Claude Code CLI in print mode
    
    // MARK: - Helper Methods
    
    private func updateSession(_ session: Session) async {
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
        let activeSessions = await MainActor.run { sessions.filter({ $0.isActive }) }
        for session in activeSessions {
            try? await stopSession(session)
        }
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