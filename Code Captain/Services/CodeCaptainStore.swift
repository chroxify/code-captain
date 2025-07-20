import Foundation
import Combine

@MainActor
class CodeCaptainStore: ObservableObject {
    private let logger = Logger.shared
    @Published var projects: [Project] = []
    @Published var sessions: [Session] = []
    @Published var selectedProject: Project?
    @Published var selectedSession: Session?
    @Published var selectedSessionId: UUID?
    @Published var isLoading = false
    @Published var error: String?
    @Published var scrollToMessage: UUID?
    
    private let projectService: ProjectService
    private let sessionService: SessionService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Persistence Keys
    private enum UserDefaultsKeys {
        static let lastSelectedSessionId = "CodeCaptain.lastSelectedSessionId"
    }
    
    init() {
        self.projectService = ProjectService()
        self.sessionService = SessionService(
            projectService: projectService
        )
        
        setupBindings()
        loadPersistedState()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind project service to store
        projectService.$projects
            .assign(to: &$projects)
        
        // Bind session service to store
        sessionService.$sessions
            .assign(to: &$sessions)
        
        // Auto-select first project if none selected
        $projects
            .compactMap { $0.first }
            .filter { [weak self] _ in self?.selectedProject == nil }
            .assign(to: &$selectedProject)
        
        // Keep selectedSession in sync with sessions updates and selectedSessionId
        sessionService.$sessions
            .combineLatest($selectedSessionId)
            .compactMap { sessions, selectedSessionId in
                guard let selectedSessionId = selectedSessionId else { return nil }
                return sessions.first { $0.id == selectedSessionId }
            }
            .assign(to: &$selectedSession)
        
        // Handle selectedSessionId changes from UI selection (async to avoid publish cycles)
        $selectedSessionId
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] sessionId in
                guard let self = self else { return }
                
                // Find the session and update related state asynchronously
                if let session = self.sessions.first(where: { $0.id == sessionId }),
                   self.selectedSession?.id != session.id {
                    
                    // Update selectedProject asynchronously to avoid publish cycles
                    Task { @MainActor in
                        if let project = self.projects.first(where: { $0.id == session.projectId }) {
                            self.selectedProject = project
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Save selectedSessionId to UserDefaults when it changes
        $selectedSessionId
            .sink { sessionId in
                if let sessionId = sessionId {
                    UserDefaults.standard.set(sessionId.uuidString, forKey: UserDefaultsKeys.lastSelectedSessionId)
                } else {
                    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastSelectedSessionId)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    
    private func loadPersistedState() {
        // Load last selected session ID
        if let sessionIdString = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastSelectedSessionId),
           let sessionId = UUID(uuidString: sessionIdString) {
            
            // Wait for sessions to be loaded, then restore selection
            sessionService.$sessions
                .first { !$0.isEmpty } // Wait for sessions to be loaded
                .sink { [weak self] sessions in
                    guard let self = self else { return }
                    
                    // Check if the persisted session still exists
                    if sessions.contains(where: { $0.id == sessionId }) {
                        self.selectedSessionId = sessionId
                        Logger.shared.info("Restored last selected session: \(sessionId)", category: .app)
                    } else {
                        // Session no longer exists, clear persisted state
                        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastSelectedSessionId)
                        Logger.shared.info("Last selected session no longer exists, cleared persisted state", category: .app)
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Project Management
    
    func addProject(name: String, path: URL, providerType: ProviderType = .claudeCode) async {
        logger.logFunctionEntry(category: .app)
        logger.info("Adding project: '\(name)' at path: '\(path.path)' with provider: '\(providerType)'", category: .app)
        
        isLoading = true
        error = nil
        
        do {
            logger.debug("Creating project via ProjectService", category: .app)
            let project = try await projectService.createProject(
                name: name,
                path: path,
                providerType: providerType
            )
            
            logger.debug("Project created successfully with ID: \(project.id)", category: .app)
            
            // Auto-select the new project
            selectedProject = project
            selectedSession = nil
            selectedSessionId = nil
            logger.debug("Auto-selected new project: \(project.name)", category: .app)
            
            logger.info("Successfully added project: '\(name)'", category: .app)
            
        } catch {
            logger.error("Failed to add project: '\(name)'", category: .app)
            logger.logError(error, category: .app)
            self.error = error.localizedDescription
        }
        
        isLoading = false
        logger.logFunctionExit(category: .app)
    }
    
    func removeProject(_ project: Project) async {
        isLoading = true
        error = nil
        
        do {
            // Sessions are conceptually always active, just remove the project
            try await projectService.removeProject(project)
            
            // Clear selection if this was the selected project
            if selectedProject?.id == project.id {
                selectedProject = projects.first
                selectedSession = nil
                selectedSessionId = nil
            }
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Session Management
    
    func createSession(for project: Project, name: String) async {
        isLoading = true
        error = nil
        
        do {
            let session = try await sessionService.createSession(for: project, name: name)
            selectedSession = session
            selectedSessionId = session.id
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func initializeSession(_ session: Session) async {
        error = nil
        
        do {
            try await sessionService.initializeSession(session)
            selectedSession = session
            selectedSessionId = session.id
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    
    
    
    func deleteSession(_ session: Session) async {
        error = nil
        
        do {
            try await sessionService.deleteSession(session)
            
            // Clear selection if this was the selected session
            if selectedSession?.id == session.id {
                let firstSession = getSessionsForProject(selectedProject)?.first
                selectedSession = firstSession
                selectedSessionId = firstSession?.id
            }
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func sendMessage(_ content: String, to session: Session) async {
        error = nil
        
        do {
            try await sessionService.sendMessage(content, to: session)
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func sendMessageStream(_ content: String, to session: Session) -> AsyncStream<Message> {
        error = nil
        return sessionService.sendMessageStream(content, to: session)
    }
    
    func queueSession(_ session: Session) async {
        error = nil
        
        do {
            try await sessionService.queueSession(session)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func archiveSession(_ session: Session) async {
        error = nil
        
        do {
            try await sessionService.archiveSession(session)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func unarchiveSession(_ session: Session) async {
        error = nil
        
        do {
            try await sessionService.unarchiveSession(session)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func updateSessionPriority(_ session: Session, priority: SessionPriority) async {
        error = nil
        
        do {
            try await sessionService.updateSessionPriority(session, priority: priority)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Bulk Operations
    
    func processNextQueuedSession() async {
        error = nil
        
        // Get highest priority queued session
        let queuedSessions = sessions.filter { $0.state == .queued }
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
        
        if let nextSession = queuedSessions.first {
            do {
                try await sessionService.initializeSession(nextSession)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    func markAllReadySessionsAsIdle() async {
        error = nil
        
        let readySessions = sessions.filter { $0.state == .readyForReview }
        for session in readySessions {
            var updatedSession = session
            updatedSession.updateState(.idle)
            // Update the session in the service
            await sessionService.updateSession(updatedSession)
        }
    }
    
    func archiveAllFailedSessions() async {
        error = nil
        
        let failedSessions = sessions.filter { $0.state == .failed || $0.state == .error }
        for session in failedSessions {
            do {
                try await sessionService.archiveSession(session)
            } catch {
                self.error = error.localizedDescription
                break
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func isProviderAvailable(_ providerType: ProviderType) -> Bool {
        // For now, Claude Code is always available if installed
        return true
    }
    
    func getProviderVersion(for type: ProviderType) async -> String? {
        return await sessionService.getProviderVersion(for: type)
    }
    
    // MARK: - Terminal Management
    // Terminal management is now handled by SwiftTerminalService directly in the views
    
    func getSessionsForProject(_ project: Project?) -> [Session]? {
        guard let project = project else { return nil }
        return sessions.filter { $0.projectId == project.id }
    }
    
    func getProcessingSessionsForProject(_ project: Project?) -> [Session] {
        guard let project = project else { return [] }
        return sessions.filter { $0.projectId == project.id && $0.state == .processing }
    }
    
    func getSession(by id: UUID) -> Session? {
        return sessions.first { $0.id == id }
    }
    
    func getTotalProcessingSessions() -> Int {
        return sessions.filter { $0.state == .processing }.count
    }
    
    func selectProject(_ project: Project) {
        selectedProject = project
        
        // Auto-select first session for this project
        if let firstSession = getSessionsForProject(project)?.first {
            selectedSession = firstSession
            selectedSessionId = firstSession.id
        } else {
            selectedSession = nil
            selectedSessionId = nil
        }
    }
    
    func selectSession(_ session: Session) {
        selectedSession = session
        selectedSessionId = session.id
        
        // Auto-select the project for this session
        if let project = projects.first(where: { $0.id == session.projectId }) {
            selectedProject = project
        }
    }
    
    // MARK: - Legacy Checkpoint Management (Deprecated)
    
    func getCheckpoints(for session: Session) -> [Checkpoint] {
        // Legacy checkpoint support - return empty array
        return []
    }
    
    func getCheckpoint(for messageId: UUID) -> Checkpoint? {
        // Legacy checkpoint support - return nil
        return nil
    }
    
    func rollbackToCheckpoint(_ checkpoint: Checkpoint) async {
        // Legacy checkpoint support - no-op
        error = "Legacy checkpoint system is deprecated. Use file state rollback instead."
    }
    
    func rollbackToCheckpointSelectively(_ checkpoint: Checkpoint, preservingOtherSessions otherSessionIds: [UUID]) async {
        // Legacy checkpoint support - no-op
        error = "Legacy checkpoint system is deprecated. Use file state rollback instead."
    }
    
    // MARK: - File State Management
    
    func hasFileChanges(for session: Session) -> Bool {
        return sessionService.hasFileChanges(for: session)
    }
    
    func getFileChangesSummary(for session: Session) -> SessionFileChangesSummary? {
        return sessionService.getFileChangesSummary(for: session)
    }
    
    func messageHasFileChanges(messageId: UUID, sessionId: UUID) -> Bool {
        return sessionService.messageHasFileChanges(messageId: messageId, sessionId: sessionId)
    }
    
    func getMessageFileChangesSummary(messageId: UUID, sessionId: UUID) -> MessageFileChangesSummary? {
        return sessionService.getMessageFileChangesSummary(messageId: messageId, sessionId: sessionId)
    }
    
    /// Get count of checkpoints that would be rolled back
    func getCheckpointRollbackCount(targetMessageId: UUID, session: Session) -> Int {
        return sessionService.getCheckpointRollbackCount(targetMessageId: targetMessageId, session: session)
    }
    
    func rollbackMessage(messageId: UUID, session: Session) async {
        error = nil
        
        do {
            try await sessionService.rollbackMessage(messageId: messageId, session: session)
            // Force UI refresh by triggering objectWillChange
            await MainActor.run {
                objectWillChange.send()
            }
            logger.info("Rollback completed for message \(messageId) in session \(session.id)", category: .fileTracking)
        } catch {
            self.error = error.localizedDescription
            logger.error("Rollback failed for message \(messageId): \(error)", category: .fileTracking)
        }
    }
    
    func rollbackToMessage(targetMessageId: UUID, session: Session) async {
        error = nil
        
        do {
            try await sessionService.rollbackToMessage(targetMessageId: targetMessageId, session: session)
            // Force UI refresh by triggering objectWillChange
            await MainActor.run {
                objectWillChange.send()
            }
            logger.info("Rollback completed to message \(targetMessageId) in session \(session.id)", category: .fileTracking)
        } catch {
            self.error = error.localizedDescription
            logger.error("Rollback to message \(targetMessageId) failed: \(error)", category: .fileTracking)
        }
    }
    
    func previewMessageRollback(messageId: UUID, sessionId: UUID) -> MessageRollbackPreview? {
        return sessionService.previewMessageRollback(messageId: messageId, sessionId: sessionId)
    }
    
    func previewRollback(toCheckpoint checkpoint: Checkpoint, excludingOtherSessions otherSessionIds: [UUID] = []) -> RollbackPreview {
        // Legacy checkpoint support - create a dummy preview with the provided checkpoint
        return RollbackPreview(
            targetCheckpoint: checkpoint,
            affectedCheckpoints: [],
            filesToRevert: [],
            conflictingFiles: [],
            protectedCheckpoints: []
        )
    }
    
    // MARK: - Cleanup
    
    func cleanup() async {
        await sessionService.cleanup()
        // Terminal cleanup is now handled by SwiftTerminalService instances
    }
}