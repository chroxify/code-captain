import Foundation
import Combine

/// Enhanced file tracker with dual-hook system for bulletproof file operation detection
/// Intercepts both tool use (pre-capture) and tool result (post-capture) at the perfect timing
class EnhancedFileTracker: ObservableObject {
    private let logger = Logger.shared
    private let fileContentManager = FileContentManager()
    private let bashDetector = BashFileOperationDetector()
    
    // Simplified file tracking - operations recorded immediately
    // Except for file creation which requires waiting for tool completion
    private var pendingCreateOperations: [String: PendingCreateOperation] = [:] // toolUseId -> PendingCreateOperation
    
    init() {
        logger.info("EnhancedFileTracker initialized - Dual-hook system ready", category: .fileTracking)
    }
    
    // MARK: - Hook 1: Tool Use Detection (Pre-Capture)
    
    /// Process tool use immediately when detected in streaming message
    func processToolUse(_ toolUse: ToolUseBlock, messageId: UUID, projectPath: URL) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        switch toolUse.name {
        case "Read":
            await handleReadToolUse(toolUse, messageId: messageId, projectPath: projectPath)
        case "Edit":
            await handleEditToolUse(toolUse, messageId: messageId, projectPath: projectPath)
        case "MultiEdit":
            await handleMultiEditToolUse(toolUse, messageId: messageId, projectPath: projectPath)
        case "Write":
            await handleWriteToolUse(toolUse, messageId: messageId, projectPath: projectPath)
        case "Bash":
            await handleBashToolUse(toolUse, messageId: messageId, projectPath: projectPath)
        default:
            // Unknown tool, skip tracking
            return
        }
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.debug("Processed tool use \(toolUse.name) in \(String(format: "%.1f", duration))ms", category: .fileTracking)
    }
    
    // MARK: - Tool Result Processing (For File Creation Only)
    
    /// Process tool result for pending file creation operations
    func processToolResult(_ toolResult: ToolResultBlock, messageId: UUID, projectPath: URL) async {
        // Only process if we have a pending create operation for this tool use
        guard let pendingOp = pendingCreateOperations.removeValue(forKey: toolResult.tool_use_id) else {
            return // No pending create operation, skip
        }
        
        do {
            // Now the file should exist, record the creation
            try await fileContentManager.recordFileCreation(
                filePath: pendingOp.filePath,
                projectPath: projectPath,
                messageId: pendingOp.messageId
            )
            
            logger.debug("Recorded file creation after tool completion: \(pendingOp.filePath)", category: .fileTracking)
        } catch {
            logger.error("Failed to record file creation after tool completion \(pendingOp.filePath): \(error)", category: .fileTracking)
        }
    }
    
    // MARK: - Tool Use Handlers (Pre-Capture)
    
    private func handleReadToolUse(_ toolUse: ToolUseBlock, messageId: UUID, projectPath: URL) async {
        guard let filePath = toolUse.input["file_path"]?.value as? String else {
            logger.warning("Read tool use missing file_path parameter", category: .fileTracking)
            return
        }
        
        do {
            // INSTANT pre-capture of original content
            try await fileContentManager.captureOriginalContent(
                filePath: filePath, 
                projectPath: projectPath, 
                messageId: messageId
            )
            
            logger.debug("Pre-captured content for Read: \(filePath)", category: .fileTracking)
        } catch {
            logger.error("Failed to pre-capture content for Read \(filePath): \(error)", category: .fileTracking)
        }
    }
    
    private func handleEditToolUse(_ toolUse: ToolUseBlock, messageId: UUID, projectPath: URL) async {
        guard let filePath = toolUse.input["file_path"]?.value as? String else {
            logger.warning("Edit tool use missing file_path parameter", category: .fileTracking)
            return
        }
        
        do {
            // INSTANT pre-capture of original content before edit
            try await fileContentManager.captureOriginalContent(
                filePath: filePath, 
                projectPath: projectPath, 
                messageId: messageId
            )
            
            // Record the modify operation immediately (simplified approach)
            try await fileContentManager.captureModifiedContent(
                filePath: filePath,
                projectPath: projectPath, 
                messageId: messageId,
                operationType: FileOperationType.modify
            )
            
            logger.debug("Recorded Edit operation for: \(filePath)", category: .fileTracking)
        } catch {
            logger.error("Failed to record Edit operation \(filePath): \(error)", category: .fileTracking)
        }
    }
    
    private func handleMultiEditToolUse(_ toolUse: ToolUseBlock, messageId: UUID, projectPath: URL) async {
        guard let filePath = toolUse.input["file_path"]?.value as? String else {
            logger.warning("MultiEdit tool use missing file_path parameter", category: .fileTracking)
            return
        }
        
        do {
            // INSTANT pre-capture of original content before multi-edit
            try await fileContentManager.captureOriginalContent(
                filePath: filePath, 
                projectPath: projectPath, 
                messageId: messageId
            )
            
            // Record the modify operation immediately (simplified approach)
            try await fileContentManager.captureModifiedContent(
                filePath: filePath,
                projectPath: projectPath, 
                messageId: messageId,
                operationType: FileOperationType.modify
            )
            
            logger.debug("Recorded MultiEdit operation for: \(filePath)", category: .fileTracking)
        } catch {
            logger.error("Failed to record MultiEdit operation \(filePath): \(error)", category: .fileTracking)
        }
    }
    
    private func handleWriteToolUse(_ toolUse: ToolUseBlock, messageId: UUID, projectPath: URL) async {
        guard let filePath = toolUse.input["file_path"]?.value as? String else {
            logger.warning("Write tool use missing file_path parameter", category: .fileTracking)
            return
        }
        
        let fullPath = projectPath.appendingPathComponent(filePath)
        let fileExists = FileManager.default.fileExists(atPath: fullPath.path)
        
        do {
            if fileExists {
                // Pre-capture existing content before overwrite
                try await fileContentManager.captureOriginalContent(
                    filePath: filePath, 
                    projectPath: projectPath, 
                    messageId: messageId
                )
                
                // Record the modify operation immediately
                try await fileContentManager.captureModifiedContent(
                    filePath: filePath,
                    projectPath: projectPath, 
                    messageId: messageId,
                    operationType: FileOperationType.modify
                )
                
                logger.debug("Recorded Write (modify) operation for: \(filePath)", category: .fileTracking)
            } else {
                // For file creation, we need to wait until after tool completion
                // Just store a pending create operation
                pendingCreateOperations[toolUse.id] = PendingCreateOperation(
                    filePath: filePath,
                    messageId: messageId,
                    toolUseId: toolUse.id
                )
                
                logger.debug("Queued Write (create) operation for: \(filePath)", category: .fileTracking)
            }
            
        } catch {
            logger.error("Failed to process Write operation \(filePath): \(error)", category: .fileTracking)
        }
    }
    
    private func handleBashToolUse(_ toolUse: ToolUseBlock, messageId: UUID, projectPath: URL) async {
        guard let command = toolUse.input["command"]?.value as? String else {
            logger.warning("Bash tool use missing command parameter", category: .fileTracking)
            return
        }
        
        // Analyze bash command for potential file operations
        let predictions = bashDetector.predictFileOperations(command: command, projectPath: projectPath)
        
        // Pre-capture content for files that might be modified or deleted
        for prediction in predictions {
            switch prediction.type {
            case .modify, .delete:
                do {
                    try await fileContentManager.captureOriginalContent(
                        filePath: prediction.filePath, 
                        projectPath: projectPath, 
                        messageId: messageId
                    )
                    logger.debug("Pre-captured content for bash operation: \(prediction.filePath)", category: .fileTracking)
                } catch {
                    logger.error("Failed to pre-capture for bash operation \(prediction.filePath): \(error)", category: .fileTracking)
                }
            case .create, .rename, .move, .copy:
                // No pre-capture needed for file creation, rename, move, or copy
                break
            }
        }
        
        // Record predicted operations immediately (simplified approach)
        for prediction in predictions {
            do {
                switch prediction.type {
                case .create:
                    try await fileContentManager.recordFileCreation(
                        filePath: prediction.filePath,
                        projectPath: projectPath,
                        messageId: messageId
                    )
                case .modify:
                    try await fileContentManager.captureModifiedContent(
                        filePath: prediction.filePath,
                        projectPath: projectPath,
                        messageId: messageId,
                        operationType: FileOperationType.modify
                    )
                case .delete:
                    try await fileContentManager.recordFileDeletion(
                        filePath: prediction.filePath,
                        projectPath: projectPath,
                        messageId: messageId
                    )
                case .rename, .move:
                    try await fileContentManager.captureModifiedContent(
                        filePath: prediction.filePath,
                        projectPath: projectPath,
                        messageId: messageId,
                        operationType: FileOperationType.move
                    )
                case .copy:
                    try await fileContentManager.recordFileCreation(
                        filePath: prediction.filePath,
                        projectPath: projectPath,
                        messageId: messageId
                    )
                }
            } catch {
                logger.error("Failed to record bash operation \(prediction.type) for \(prediction.filePath): \(error)", category: .fileTracking)
            }
        }
        
        logger.debug("Recorded \(predictions.count) bash operations", category: .fileTracking)
    }
    
    // MARK: - Public Interface
    
    /// Rollback all file operations for a message
    func rollbackMessage(messageId: UUID, projectPath: URL) async throws {
        try await fileContentManager.rollbackMessage(messageId: messageId, projectPath: projectPath)
        logger.info("Message rollback completed: \(messageId)", category: .fileTracking)
    }
    
    /// Atomic checkpoint rollback - rollback multiple messages in correct order
    func rollbackToCheckpoint(targetMessageId: UUID, messagesToRollback: [UUID], projectPath: URL) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        logger.info("Starting atomic checkpoint rollback - \(messagesToRollback.count) checkpoints to rollback", category: .fileTracking)
        
        // Process checkpoints sequentially to avoid race conditions
        var results: [(Bool, UUID, Error?)] = []
        
        // Process each message rollback sequentially (in reverse order for proper rollback)
        for messageId in messagesToRollback.reversed() {
            do {
                try await fileContentManager.rollbackMessage(messageId: messageId, projectPath: projectPath)
                results.append((true, messageId, nil))
            } catch {
                results.append((false, messageId, error))
            }
        }
        
        // Check if all checkpoints were rolled back successfully
        let failures = results.filter { !$0.0 }
        if failures.isEmpty {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.info("Atomic checkpoint rollback completed - \(messagesToRollback.count) checkpoints in \(String(format: "%.1f", duration))ms", category: .fileTracking)
        } else {
            let errors = failures.compactMap { $0.2 }
            for (_, messageId, error) in failures {
                logger.error("Failed to rollback checkpoint \(messageId): \(error?.localizedDescription ?? "unknown error")", category: .fileTracking)
            }
            throw FileContentError.rollbackFailed(targetMessageId, errors)
        }
    }
    
    /// Check if a message has trackable file operations
    func hasFileOperations(messageId: UUID) -> Bool {
        return fileContentManager.hasFileOperations(messageId: messageId)
    }
    
    /// Get comprehensive file changes summary (all messages)
    func getFileChangesSummary() -> FileChangesSummary {
        return fileContentManager.getFileChangesSummary()
    }
    
    /// Get file changes summary for specific messages in a session
    func getFileChangesSummary(forMessages messageIds: [UUID]) -> FileChangesSummary {
        return fileContentManager.getFileChangesSummary(forMessages: messageIds)
    }
    
    /// Get performance metrics
    func getPerformanceMetrics() -> PerformanceMetrics {
        return fileContentManager.getPerformanceMetrics()
    }
    
    /// Clear all cached data
    func clearCache() {
        fileContentManager.clearAllCache()
        pendingCreateOperations.removeAll()
    }
}

// MARK: - Supporting Data Structures

struct PendingCreateOperation {
    let filePath: String
    let messageId: UUID
    let toolUseId: String
}

struct FileOperationPrediction {
    let type: FileOperationType
    let filePath: String
    let confidence: Double // 0.0 to 1.0
}

struct DetectedFileOperation {
    let type: FileOperationType
    let filePath: String
}