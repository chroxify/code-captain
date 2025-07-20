import Foundation

// MARK: - File Changes Summary Types

/// Comprehensive file changes summary for a session
struct SessionFileChangesSummary {
    let modifiedFiles: [String]
    let createdFiles: [String]
    let deletedFiles: [String]
    let renamedFiles: [(from: String, to: String)]
    let totalOperations: Int
    let messageCount: Int
    
    var totalFilesAffected: Int {
        Set(modifiedFiles + createdFiles + deletedFiles + renamedFiles.map { $0.to }).count
    }
    
    var hasChanges: Bool {
        totalOperations > 0
    }
    
    var displaySummary: String {
        var parts: [String] = []
        
        if !modifiedFiles.isEmpty { parts.append("\(modifiedFiles.count) modified") }
        if !createdFiles.isEmpty { parts.append("\(createdFiles.count) created") }
        if !deletedFiles.isEmpty { parts.append("\(deletedFiles.count) deleted") }
        if !renamedFiles.isEmpty { parts.append("\(renamedFiles.count) renamed") }
        
        if parts.isEmpty { return "No changes" }
        return parts.joined(separator: ", ")
    }
}

/// File changes summary for a specific message
struct MessageFileChangesSummary {
    let affectedFiles: [String]
    let operationCounts: [String: Int] // Simplified from MessageFileOperationType
    let totalOperations: Int
    
    var hasChanges: Bool {
        totalOperations > 0
    }
    
    var displaySummary: String {
        let operations = operationCounts.map { "\($0.value) \($0.key.lowercased())" }
        return operations.joined(separator: ", ")
    }
}

/// Preview of what would be rolled back for a message
struct MessageRollbackPreview {
    let messageId: UUID
    let filesToRestore: [String]
    let filesToDelete: [String]
    let operationsPreview: [FileOperationPreview]
    
    var hasChanges: Bool {
        !filesToRestore.isEmpty || !filesToDelete.isEmpty
    }
}

struct FileOperationPreview {
    let filePath: String
    let operation: String
    let summary: String
}