import Foundation

// MARK: - Checkpoint Models

struct Checkpoint: Identifiable, Codable, Hashable {
    let id: UUID
    let messageId: UUID
    let sessionId: UUID
    let projectId: UUID
    let gitCommitHash: String
    let branchName: String
    let createdAt: Date
    let description: String
    let fileOperations: [CheckpointFileOperation]
    let metadata: CheckpointMetadata
    
    init(messageId: UUID, sessionId: UUID, projectId: UUID, gitCommitHash: String, branchName: String, description: String, fileOperations: [CheckpointFileOperation], metadata: CheckpointMetadata) {
        self.id = UUID()
        self.messageId = messageId
        self.sessionId = sessionId
        self.projectId = projectId
        self.gitCommitHash = gitCommitHash
        self.branchName = branchName
        self.createdAt = Date()
        self.description = description
        self.fileOperations = fileOperations
        self.metadata = metadata
    }
    
    var displayName: String {
        if description.isEmpty {
            return "Checkpoint \(id.uuidString.prefix(8))"
        } else {
            return description.prefix(50) + (description.count > 50 ? "..." : "")
        }
    }
    
    var filesChangedCount: Int {
        fileOperations.count
    }
    
    var hasFileChanges: Bool {
        !fileOperations.isEmpty
    }
    
    /// Get unique list of file paths that were modified in this checkpoint
    var modifiedFilePaths: [String] {
        Array(Set(fileOperations.map { $0.filePath }))
    }
    
    /// Check if this checkpoint modified a specific file
    func didModifyFile(_ filePath: String) -> Bool {
        fileOperations.contains { $0.filePath == filePath }
    }
    
    /// Get file operations for a specific file
    func fileOperations(for filePath: String) -> [CheckpointFileOperation] {
        fileOperations.filter { $0.filePath == filePath }
    }
}

struct CheckpointFileOperation: Identifiable, Codable, Hashable {
    let id: UUID
    let filePath: String
    let operationType: FileOperationType
    let toolName: String
    let toolId: String?
    let timestamp: Date
    let contentHash: String?
    let lineChanges: LineChanges?
    let contentPreview: String?
    
    init(filePath: String, operationType: FileOperationType, toolName: String, toolId: String? = nil, contentHash: String? = nil, lineChanges: LineChanges? = nil, contentPreview: String? = nil) {
        self.id = UUID()
        self.filePath = filePath
        self.operationType = operationType
        self.toolName = toolName
        self.toolId = toolId
        self.timestamp = Date()
        self.contentHash = contentHash
        self.lineChanges = lineChanges
        self.contentPreview = contentPreview
    }
    
    var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }
    
    var displayPath: String {
        // Show relative path from project root
        if filePath.contains("/") {
            let components = filePath.components(separatedBy: "/")
            if components.count > 2 {
                return ".../" + components.suffix(2).joined(separator: "/")
            }
        }
        return filePath
    }
    
    var displayDescription: String {
        "\(operationType.displayName) \(fileName) with \(toolName)"
    }
}

enum FileOperationType: String, CaseIterable, Codable, Hashable {
    case create = "create"
    case modify = "modify"
    case delete = "delete"
    case rename = "rename"
    case move = "move"
    case copy = "copy"
    
    var displayName: String {
        switch self {
        case .create: return "Created"
        case .modify: return "Modified"
        case .delete: return "Deleted"
        case .rename: return "Renamed"
        case .move: return "Moved"
        case .copy: return "Copied"
        }
    }
    
    var iconName: String {
        switch self {
        case .create: return "plus.circle"
        case .modify: return "pencil"
        case .delete: return "trash"
        case .rename: return "arrow.triangle.2.circlepath"
        case .move: return "arrow.right.circle"
        case .copy: return "doc.on.doc"
        }
    }
    
    var color: String {
        switch self {
        case .create: return "green"
        case .modify: return "blue"
        case .delete: return "red"
        case .rename: return "orange"
        case .move: return "purple"
        case .copy: return "teal"
        }
    }
}

struct LineChanges: Codable, Hashable {
    let linesAdded: Int
    let linesRemoved: Int
    let linesModified: Int
    let affectedLineRanges: [LineRange]
    
    var totalChanges: Int {
        linesAdded + linesRemoved + linesModified
    }
    
    var displaySummary: String {
        var parts: [String] = []
        if linesAdded > 0 { parts.append("+\(linesAdded)") }
        if linesRemoved > 0 { parts.append("-\(linesRemoved)") }
        if linesModified > 0 { parts.append("~\(linesModified)") }
        return parts.joined(separator: " ")
    }
}

struct LineRange: Codable, Hashable {
    let startLine: Int
    let endLine: Int
    
    var displayRange: String {
        if startLine == endLine {
            return "L\(startLine)"
        } else {
            return "L\(startLine)-\(endLine)"
        }
    }
}

struct CheckpointMetadata: Codable, Hashable {
    let toolsUsed: [String]
    let totalExecutionTime: TimeInterval
    let messageContent: String?
    let aiModel: String?
    let costUSD: Double?
    let tokensUsed: TokenUsage?
    let hasErrors: Bool
    let errorDetails: [String]?
    
    init(toolsUsed: [String], totalExecutionTime: TimeInterval, messageContent: String? = nil, aiModel: String? = nil, costUSD: Double? = nil, tokensUsed: TokenUsage? = nil, hasErrors: Bool = false, errorDetails: [String]? = nil) {
        self.toolsUsed = toolsUsed
        self.totalExecutionTime = totalExecutionTime
        self.messageContent = messageContent
        self.aiModel = aiModel
        self.costUSD = costUSD
        self.tokensUsed = tokensUsed
        self.hasErrors = hasErrors
        self.errorDetails = errorDetails
    }
    
    var formattedExecutionTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalExecutionTime) ?? "\(Int(totalExecutionTime))s"
    }
    
    var formattedCost: String? {
        guard let cost = costUSD else { return nil }
        return String(format: "$%.4f", cost)
    }
}

struct TokenUsage: Codable, Hashable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int?
    
    var totalTokens: Int {
        inputTokens + outputTokens + (cacheTokens ?? 0)
    }
    
    var displaySummary: String {
        "\(inputTokens) in / \(outputTokens) out"
    }
}

// MARK: - Rollback Preview

struct RollbackPreview: Codable, Hashable {
    let targetCheckpoint: Checkpoint
    let affectedCheckpoints: [Checkpoint]
    let filesToRevert: [String]
    let conflictingFiles: [String]
    let protectedCheckpoints: [Checkpoint]
    
    var hasConflicts: Bool {
        !conflictingFiles.isEmpty
    }
    
    var safeFileCount: Int {
        filesToRevert.count
    }
    
    var conflictFileCount: Int {
        conflictingFiles.count
    }
    
    var totalAffectedFiles: Int {
        safeFileCount + conflictFileCount
    }
    
    var canProceedSafely: Bool {
        !filesToRevert.isEmpty
    }
    
    var warningMessage: String? {
        if hasConflicts {
            return "\(conflictFileCount) files have been modified by other sessions and cannot be safely reverted."
        }
        return nil
    }
    
    var summaryDescription: String {
        if hasConflicts {
            return "Will revert \(safeFileCount) files, \(conflictFileCount) files have conflicts"
        } else {
            return "Will revert \(safeFileCount) files with no conflicts"
        }
    }
}

// MARK: - Checkpoint Extensions

extension Checkpoint {
    static let mock = Checkpoint(
        messageId: UUID(),
        sessionId: UUID(),
        projectId: UUID(),
        gitCommitHash: "abc123def456",
        branchName: "session-abc-feature",
        description: "Added authentication middleware and updated user routes",
        fileOperations: [
            CheckpointFileOperation(filePath: "src/middleware/auth.js", operationType: .create, toolName: "Write"),
            CheckpointFileOperation(filePath: "src/routes/user.js", operationType: .modify, toolName: "Edit"),
            CheckpointFileOperation(filePath: "tests/auth.test.js", operationType: .create, toolName: "Write")
        ],
        metadata: CheckpointMetadata(
            toolsUsed: ["Write", "Edit", "Bash"],
            totalExecutionTime: 45.3,
            messageContent: "Implement user authentication system",
            aiModel: "claude-3-5-sonnet-20241022",
            costUSD: 0.0234,
            tokensUsed: TokenUsage(inputTokens: 1250, outputTokens: 890, cacheTokens: 150)
        )
    )
}