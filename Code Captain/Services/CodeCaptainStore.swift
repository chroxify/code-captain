import Foundation
import Combine

@MainActor
class CodeCaptainStore: ObservableObject {
    private let logger = Logger.shared
    @Published var projects: [Project] = []
    @Published var sessions: [Session] = []
    @Published var selectedProject: Project?
    @Published var selectedSession: Session?
    @Published var isLoading = false
    @Published var error: String?
    
    private let projectService: ProjectService
    private let sessionService: SessionService
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.projectService = ProjectService()
        self.sessionService = SessionService(
            projectService: projectService
        )
        
        setupBindings()
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
            // Stop all sessions for this project
            let projectSessions = sessions.filter { $0.projectId == project.id }
            for session in projectSessions {
                if session.isActive {
                    try await sessionService.stopSession(session)
                }
            }
            
            // Remove the project
            try await projectService.removeProject(project)
            
            // Clear selection if this was the selected project
            if selectedProject?.id == project.id {
                selectedProject = projects.first
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
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func startSession(_ session: Session) async {
        error = nil
        
        do {
            try await sessionService.startSession(session)
            selectedSession = session
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func stopSession(_ session: Session) async {
        error = nil
        
        do {
            try await sessionService.stopSession(session)
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func pauseSession(_ session: Session) async {
        error = nil
        
        do {
            try await sessionService.pauseSession(session)
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func resumeSession(_ session: Session) async {
        error = nil
        
        do {
            try await sessionService.resumeSession(session)
            
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
                selectedSession = getSessionsForProject(selectedProject)?.first
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
    
    func getActiveSessionsForProject(_ project: Project?) -> [Session] {
        guard let project = project else { return [] }
        return sessions.filter { $0.projectId == project.id && $0.isActive }
    }
    
    func getSession(by id: UUID) -> Session? {
        return sessions.first { $0.id == id }
    }
    
    func getTotalActiveSessions() -> Int {
        return sessions.filter { $0.isActive }.count
    }
    
    func selectProject(_ project: Project) {
        selectedProject = project
        
        // Auto-select first session for this project
        if let firstSession = getSessionsForProject(project)?.first {
            selectedSession = firstSession
        } else {
            selectedSession = nil
        }
    }
    
    func selectSession(_ session: Session) {
        selectedSession = session
        
        // Auto-select the project for this session
        if let project = projects.first(where: { $0.id == session.projectId }) {
            selectedProject = project
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() async {
        await sessionService.cleanup()
        // Terminal cleanup is now handled by SwiftTerminalService instances
    }
}