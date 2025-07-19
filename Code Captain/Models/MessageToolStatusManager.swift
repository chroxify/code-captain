import Foundation
import SwiftUI

// MARK: - Per-Message Tool Status Manager
/// Manages tool statuses for a specific message with proper isolation
class MessageToolStatusManager {
    
    private let messageId: UUID
    private var toolStatuses: [String: ToolStatus] = [:]
    private var processedBlockIndices: Set<Int> = []
    
    init(messageId: UUID) {
        self.messageId = messageId
    }
    
    // MARK: - Unique ID Generation
    
    /// Generate stable unique ID for content blocks
    private func generateUniqueId(blockIndex: Int, contentBlock: ContentBlock) -> String {
        let messagePrefix = messageId.uuidString.prefix(8)
        
        switch contentBlock {
        case .thinking(_):
            return "\(messagePrefix)-thinking-\(blockIndex)"
        case .toolUse(let toolUse):
            return "\(messagePrefix)-tool-\(toolUse.id)"
        case .text(_):
            return "\(messagePrefix)-text-\(blockIndex)"
        default:
            return "\(messagePrefix)-block-\(blockIndex)"
        }
    }
    
    // MARK: - Processing Methods
    
    /// Process content blocks for this specific message
    func processContentBlocks(_ contentBlocks: [ContentBlock]) -> [ToolStatus] {
        var results: [ToolStatus] = []
        
        for (index, contentBlock) in contentBlocks.enumerated() {
            // Skip if already processed
            if processedBlockIndices.contains(index) {
                if let existingStatus = getExistingStatus(for: contentBlock, at: index) {
                    results.append(existingStatus)
                }
                continue
            }
            
            let uniqueId = generateUniqueId(blockIndex: index, contentBlock: contentBlock)
            
            switch contentBlock {
            case .thinking(let thinkingBlock):
                let status = createThinkingStatus(
                    id: uniqueId,
                    thinking: thinkingBlock,
                    isCompleted: false
                )
                toolStatuses[uniqueId] = status
                results.append(status)
                
            case .toolUse(let toolUseBlock):
                let status = ToolStatusConverter.convertToProcessingStatus(toolUseBlock)
                let updatedStatus = ToolStatus(
                    id: uniqueId, // Use our unique ID
                    toolType: status.toolType,
                    state: status.state,
                    preview: status.preview,
                    fullContent: status.fullContent,
                    startTime: status.startTime,
                    endTime: status.endTime
                )
                toolStatuses[uniqueId] = updatedStatus
                results.append(updatedStatus)
                
            case .text(_):
                // Text blocks don't create ongoing states, just display content
                break
                
            default:
                break
            }
            
            processedBlockIndices.insert(index)
        }
        
        return results
    }
    
    /// Complete a tool with its result
    func completeToolWithResult(_ toolResult: ToolResultBlock) -> ToolStatus? {
        // Find the tool by original tool_use_id
        let toolKey = toolStatuses.keys.first { key in
            key.hasSuffix("tool-\(toolResult.tool_use_id)")
        }
        
        guard let key = toolKey,
              let existingTool = toolStatuses[key],
              existingTool.isProcessing else {
            return nil
        }
        
        let completedStatus = createCompletedStatus(
            from: existingTool,
            result: toolResult.content,
            isError: toolResult.is_error ?? false
        )
        
        toolStatuses[key] = completedStatus
        return completedStatus
    }
    
    // MARK: - State Management Helpers
    
    private func getExistingStatus(for contentBlock: ContentBlock, at index: Int) -> ToolStatus? {
        let uniqueId = generateUniqueId(blockIndex: index, contentBlock: contentBlock)
        return toolStatuses[uniqueId]
    }
    
    private func completeProcessingThinking() -> [ToolStatus] {
        var completedStatuses: [ToolStatus] = []
        
        for (key, status) in toolStatuses {
            if status.toolType == .task && status.isProcessing {
                let completedStatus = ToolStatus(
                    id: status.id,
                    toolType: status.toolType,
                    state: .completed(duration: Date().timeIntervalSince(status.startTime)),
                    preview: status.preview,
                    fullContent: status.fullContent,
                    startTime: status.startTime,
                    endTime: Date()
                )
                toolStatuses[key] = completedStatus
                completedStatuses.append(completedStatus)
            }
        }
        
        return completedStatuses
    }
    
    private func completeAllProcessingSteps() -> [ToolStatus] {
        var completedStatuses: [ToolStatus] = []
        
        for (key, status) in toolStatuses {
            if status.isProcessing {
                let completedStatus = ToolStatus(
                    id: status.id,
                    toolType: status.toolType,
                    state: .completed(duration: Date().timeIntervalSince(status.startTime)),
                    preview: status.preview,
                    fullContent: status.fullContent,
                    startTime: status.startTime,
                    endTime: Date()
                )
                toolStatuses[key] = completedStatus
                completedStatuses.append(completedStatus)
            }
        }
        
        return completedStatuses
    }
    
    private func createThinkingStatus(id: String, thinking: ThinkingBlock, isCompleted: Bool) -> ToolStatus {
        let preview = String(thinking.thinking.prefix(100)) + (thinking.thinking.count > 100 ? "..." : "")
        let state: ToolStatusState = isCompleted ? .completed(duration: nil) : .processing
        
        return ToolStatus(
            id: id,
            toolType: .task,
            state: state,
            preview: preview,
            fullContent: thinking.thinking
        )
    }
    
    private func createCompletedStatus(from activeStatus: ToolStatus, result: String?, isError: Bool) -> ToolStatus {
        let endTime = Date()
        let duration = endTime.timeIntervalSince(activeStatus.startTime)
        
        let state: ToolStatusState = isError ? 
            .error(message: result ?? "Unknown error") :
            .completed(duration: duration)
        
        return ToolStatus(
            id: activeStatus.id,
            toolType: activeStatus.toolType,
            state: state,
            preview: activeStatus.preview,
            fullContent: result ?? activeStatus.fullContent,
            startTime: activeStatus.startTime,
            endTime: endTime
        )
    }
    
    // MARK: - Public Interface
    
    /// Get all tool statuses for this message
    var allToolStatuses: [ToolStatus] {
        return Array(toolStatuses.values).sorted { $0.startTime < $1.startTime }
    }
    
    /// Get tool status by ID
    func getToolStatus(for id: String) -> ToolStatus? {
        return toolStatuses[id]
    }
    
    /// Reset all tool statuses
    func reset() {
        toolStatuses.removeAll()
        processedBlockIndices.removeAll()
    }
}