import Foundation
import Combine

class ProjectService: ObservableObject {
    private let logger = Logger.shared
    @Published var projects: [Project] = []
    
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let projectsKey = "CodeCaptain.Projects"
    
    init() {
        logger.logFunctionEntry(category: .project)
        loadProjects()
        logger.logFunctionExit(category: .project)
    }
    
    // MARK: - Project Management
    
    func createProject(name: String, path: URL, providerType: ProviderType = .claudeCode) async throws -> Project {
        logger.logFunctionEntry(category: .project)
        logger.info("Creating project: '\(name)' at path: '\(path.path)' with provider: '\(providerType)'", category: .project)
        
        // Validate path exists and is a directory
        logger.debug("Validating project path: \(path.path)", category: .project)
        guard fileManager.fileExists(atPath: path.path) else {
            logger.error("Project path does not exist: \(path.path)", category: .project)
            throw ProjectError.pathNotFound
        }
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            logger.error("Project path is not a directory: \(path.path)", category: .project)
            throw ProjectError.notADirectory
        }
        
        // Check if project already exists
        if projects.contains(where: { $0.path == path }) {
            logger.error("Project already exists at path: \(path.path)", category: .project)
            throw ProjectError.projectAlreadyExists
        }
        
        // Create project
        logger.debug("Creating project object", category: .project)
        var project = Project(name: name, path: path, providerType: providerType)
        
        // Set up git worktree
        logger.debug("Setting up git worktree for project", category: .project)
        do {
            try await setupGitWorktree(for: &project)
            logger.info("Successfully set up git worktree for project: \(name)", category: .project)
        } catch {
            logger.error("Failed to set up git worktree for project: \(name)", category: .project)
            logger.logError(error, category: .project)
            throw error
        }
        
        // Add to projects list on main thread
        logger.debug("Adding project to projects list", category: .project)
        await MainActor.run {
            projects.append(project)
            saveProjects()
        }
        
        logger.info("Successfully created project: '\(name)' with ID: \(project.id)", category: .project)
        logger.logFunctionExit(category: .project)
        return project
    }
    
    func removeProject(_ project: Project) async throws {
        // Clean up git worktree
        try await cleanupGitWorktree(for: project)
        
        // Remove from projects list on main thread
        await MainActor.run {
            projects.removeAll { $0.id == project.id }
            saveProjects()
        }
    }
    
    func updateProject(_ project: Project) async {
        await MainActor.run {
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = project
                saveProjects()
            }
        }
    }
    
    // MARK: - Git Worktree Management
    
    private func setupGitWorktree(for project: inout Project) async throws {
        logger.logFunctionEntry(category: .git)
        let projectPath = project.path
        let worktreePath = project.gitWorktreePath
        
        logger.debug("Setting up git worktree - Project: \(projectPath.path), Worktree: \(worktreePath.path)", category: .git)
        
        // Check if the project is a git repository
        let gitPath = projectPath.appendingPathComponent(".git")
        logger.debug("Checking if project is a git repository: \(gitPath.path)", category: .git)
        guard fileManager.fileExists(atPath: gitPath.path) else {
            logger.error("Project is not a git repository: \(projectPath.path)", category: .git)
            throw ProjectError.notAGitRepository
        }
        
        // Remove existing worktree if it exists
        if fileManager.fileExists(atPath: worktreePath.path) {
            logger.warning("Existing worktree found, removing: \(worktreePath.path)", category: .git)
            try await removeGitWorktree(at: worktreePath, from: projectPath)
        }
        
        // Create new worktree
        logger.debug("Creating new git worktree", category: .git)
        try await createGitWorktree(at: worktreePath, from: projectPath)
        
        // Verify worktree was created successfully
        guard fileManager.fileExists(atPath: worktreePath.path) else {
            logger.error("Worktree creation failed - directory does not exist: \(worktreePath.path)", category: .git)
            throw ProjectError.worktreeCreationFailed
        }
        
        logger.info("Successfully set up git worktree: \(worktreePath.path)", category: .git)
        logger.logFunctionExit(category: .git)
    }
    
    private func createGitWorktree(at worktreePath: URL, from projectPath: URL) async throws {
        logger.logFunctionEntry(category: .git)
        logger.debug("Creating git worktree at: \(worktreePath.path) from: \(projectPath.path)", category: .git)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "worktree", "add", worktreePath.path, "HEAD"]
        process.currentDirectoryURL = projectPath
        
        logger.debug("Git command: \(process.executableURL?.path ?? "unknown") \(process.arguments?.joined(separator: " ") ?? "")", category: .git)
        logger.debug("Working directory: \(projectPath.path)", category: .git)
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            logger.debug("Executing git worktree add command", category: .git)
            try process.run()
            process.waitUntilExit()
            
            logger.debug("Git command completed with status: \(process.terminationStatus)", category: .git)
            
            // Log output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let outputString = String(data: outputData, encoding: .utf8) ?? ""
            if !outputString.isEmpty {
                logger.debug("Git output: \(outputString)", category: .git)
            }
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                logger.error("Git command failed with status \(process.terminationStatus): \(errorString)", category: .git)
                throw ProjectError.gitCommandFailed(errorString)
            }
            
            logger.info("Successfully created git worktree at: \(worktreePath.path)", category: .git)
        } catch {
            logger.error("Failed to execute git worktree command", category: .git)
            logger.logError(error, category: .git)
            throw error
        }
        
        logger.logFunctionExit(category: .git)
    }
    
    private func removeGitWorktree(at worktreePath: URL, from projectPath: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "worktree", "remove", worktreePath.path, "--force"]
        process.currentDirectoryURL = projectPath
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        // Note: We don't throw error here as the worktree might not exist
        // This is expected behavior during cleanup
    }
    
    private func cleanupGitWorktree(for project: Project) async throws {
        let worktreePath = project.gitWorktreePath
        let projectPath = project.path
        
        if fileManager.fileExists(atPath: worktreePath.path) {
            try await removeGitWorktree(at: worktreePath, from: projectPath)
        }
    }
    
    // MARK: - Branch Management
    
    func createBranch(name: String, for project: Project) async throws -> String {
        let worktreePath = project.gitWorktreePath
        
        // Sanitize the session name to be git-safe
        let sanitizedName = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "~", with: "")
            .replacingOccurrences(of: "^", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "@", with: "")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let branchName = "session-\(UUID().uuidString.prefix(8))-\(sanitizedName)"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "checkout", "-b", branchName]
        process.currentDirectoryURL = worktreePath
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ProjectError.gitCommandFailed(errorString)
        }
        
        return branchName
    }
    
    func switchToBranch(name: String, for project: Project) async throws {
        let worktreePath = project.gitWorktreePath
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "checkout", name]
        process.currentDirectoryURL = worktreePath
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ProjectError.gitCommandFailed(errorString)
        }
    }
    
    // MARK: - Persistence
    
    private func saveProjects() {
        if let encoded = try? JSONEncoder().encode(projects) {
            userDefaults.set(encoded, forKey: projectsKey)
        }
    }
    
    private func loadProjects() {
        if let data = userDefaults.data(forKey: projectsKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
        }
    }
}

// MARK: - Errors

enum ProjectError: LocalizedError {
    case pathNotFound
    case notADirectory
    case notAGitRepository
    case projectAlreadyExists
    case worktreeCreationFailed
    case gitCommandFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .pathNotFound:
            return "The specified path does not exist."
        case .notADirectory:
            return "The specified path is not a directory."
        case .notAGitRepository:
            return "The specified directory is not a Git repository."
        case .projectAlreadyExists:
            return "A project with this path already exists."
        case .worktreeCreationFailed:
            return "Failed to create Git worktree."
        case .gitCommandFailed(let message):
            return "Git command failed: \(message)"
        }
    }
}