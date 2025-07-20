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
        
        // Verify git repository and initialize Code Captain tracking
        logger.debug("Initializing git repository for Code Captain", category: .project)
        do {
            try await initializeCodeCaptainGitTracking(for: &project)
            logger.info("Successfully initialized Code Captain git tracking for project: \(name)", category: .project)
        } catch {
            logger.error("Failed to initialize Code Captain git tracking for project: \(name)", category: .project)
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
        // Clean up Code Captain git branches and tracking
        try await cleanupCodeCaptainGitTracking(for: project)
        
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
    
    // MARK: - Code Captain Git Management
    
    private func initializeCodeCaptainGitTracking(for project: inout Project) async throws {
        logger.logFunctionEntry(category: .git)
        let projectPath = project.path
        
        logger.debug("Initializing Code Captain git tracking in project: \(projectPath.path)", category: .git)
        
        // Check if the project is a git repository
        let gitPath = projectPath.appendingPathComponent(".git")
        logger.debug("Checking if project is a git repository: \(gitPath.path)", category: .git)
        guard fileManager.fileExists(atPath: gitPath.path) else {
            logger.error("Project is not a git repository: \(projectPath.path)", category: .git)
            throw ProjectError.notAGitRepository
        }
        
        // Store current branch for restoration later if needed
        let currentBranch = try await getCurrentBranch(in: projectPath)
        logger.debug("Current branch: \(currentBranch)", category: .git)
        
        // Create CodeCaptain directory for metadata (not a worktree)
        let codeCaptainDir = projectPath.appendingPathComponent("CodeCaptain")
        if !fileManager.fileExists(atPath: codeCaptainDir.path) {
            try fileManager.createDirectory(at: codeCaptainDir, withIntermediateDirectories: true)
            logger.debug("Created CodeCaptain metadata directory", category: .git)
        }
        
        logger.info("Successfully initialized Code Captain git tracking: \(projectPath.path)", category: .git)
        logger.logFunctionExit(category: .git)
    }
    
    /// Get the current git branch
    private func getCurrentBranch(in projectPath: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "branch", "--show-current"]
        process.currentDirectoryURL = projectPath
        
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
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let branchName = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "main"
        
        return branchName.isEmpty ? "main" : branchName
    }
    
    /// Clean up Code Captain branches and tracking
    private func cleanupCodeCaptainGitTracking(for project: Project) async throws {
        let projectPath = project.path
        
        // List all Code Captain session branches
        let branches = try await listCodeCaptainBranches(in: projectPath)
        
        // Delete each Code Captain branch
        for branch in branches {
            try await deleteBranch(name: branch, in: projectPath)
        }
        
        // Remove CodeCaptain metadata directory
        let codeCaptainDir = projectPath.appendingPathComponent("CodeCaptain")
        if fileManager.fileExists(atPath: codeCaptainDir.path) {
            try fileManager.removeItem(at: codeCaptainDir)
        }
    }
    
    /// List all Code Captain session branches
    private func listCodeCaptainBranches(in projectPath: URL) async throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "branch", "--list", "codecaptain/*"]
        process.currentDirectoryURL = projectPath
        
        let outputPipe = Pipe()
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        return output.components(separatedBy: .newlines)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("* ") {
                    return String(trimmed.dropFirst(2))
                } else if trimmed.hasPrefix("  ") {
                    return String(trimmed.dropFirst(2))
                }
                return trimmed.isEmpty ? nil : trimmed
            }
    }
    
    /// Delete a git branch
    private func deleteBranch(name: String, in projectPath: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "branch", "-D", name]
        process.currentDirectoryURL = projectPath
        
        try process.run()
        process.waitUntilExit()
        // Don't throw error if branch doesn't exist
    }
    
    // MARK: - Branch Management
    
    func createBranch(name: String, for project: Project) async throws -> String {
        let projectPath = project.gitWorktreePath  // This is now the same as project.path
        
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
        
        // Use CodeCaptain namespace for branches: codecaptain/session-id
        let sessionId = UUID().uuidString.prefix(8)
        let branchName = "codecaptain/\(sessionId)"
        
        logger.debug("Creating Code Captain branch: \(branchName) for session: \(name)", category: .git)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "checkout", "-b", branchName]
        process.currentDirectoryURL = projectPath
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to create branch \(branchName): \(errorString)", category: .git)
            throw ProjectError.gitCommandFailed(errorString)
        }
        
        logger.info("Successfully created Code Captain branch: \(branchName)", category: .git)
        return branchName
    }
    
    func switchToBranch(name: String, for project: Project) async throws {
        let projectPath = project.gitWorktreePath  // This is now the same as project.path
        
        logger.debug("Switching to Code Captain branch: \(name)", category: .git)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "checkout", name]
        process.currentDirectoryURL = projectPath
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to switch to branch \(name): \(errorString)", category: .git)
            throw ProjectError.gitCommandFailed(errorString)
        }
        
        logger.info("Successfully switched to Code Captain branch: \(name)", category: .git)
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