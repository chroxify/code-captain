import Foundation

/// Smart bash command analyzer that predicts file operations from complex shell commands
/// Uses pattern matching and heuristics to detect file creation, modification, deletion, etc.
class BashFileOperationDetector {
    private let logger = Logger.shared
    
    // Common file operation patterns with confidence scores
    private let operationPatterns: [FileOperationPattern]
    
    private static func createOperationPatterns() -> [FileOperationPattern] {
        var patterns: [FileOperationPattern] = []
        
        // File creation
        patterns.append(FileOperationPattern(regex: #"touch\s+([^\s;|&]+)"#, type: .create, confidence: 0.95))
        patterns.append(FileOperationPattern(regex: #"echo\s+.*\s*>\s*([^\s;|&]+)"#, type: .create, confidence: 0.90))
        patterns.append(FileOperationPattern(regex: #"cat\s+.*\s*>\s*([^\s;|&]+)"#, type: .create, confidence: 0.85))
        patterns.append(FileOperationPattern(regex: #"printf\s+.*\s*>\s*([^\s;|&]+)"#, type: .create, confidence: 0.85))
        
        // File modification
        patterns.append(FileOperationPattern(regex: #"echo\s+.*\s*>>\s*([^\s;|&]+)"#, type: .modify, confidence: 0.90))
        patterns.append(FileOperationPattern(regex: #"cat\s+.*\s*>>\s*([^\s;|&]+)"#, type: .modify, confidence: 0.85))
        patterns.append(FileOperationPattern(regex: #"sed\s+.*\s+-i[^\s]*\s+([^\s;|&]+)"#, type: .modify, confidence: 0.95))
        patterns.append(FileOperationPattern(regex: #"awk\s+.*\s+-i\s+([^\s;|&]+)"#, type: .modify, confidence: 0.85))
        patterns.append(FileOperationPattern(regex: #"perl\s+.*\s+-i[^\s]*\s+([^\s;|&]+)"#, type: .modify, confidence: 0.90))
        
        // File deletion
        patterns.append(FileOperationPattern(regex: #"rm\s+(?:-[rf]+\s+)?([^\s;|&]+)"#, type: .delete, confidence: 0.98))
        patterns.append(FileOperationPattern(regex: #"rmdir\s+([^\s;|&]+)"#, type: .delete, confidence: 0.95))
        
        // File operations
        patterns.append(FileOperationPattern(regex: #"cp\s+[^\s;|&]+\s+([^\s;|&]+)"#, type: .copy, confidence: 0.90))
        patterns.append(FileOperationPattern(regex: #"mv\s+([^\s;|&]+)\s+([^\s;|&]+)"#, type: .move, confidence: 0.95))
        patterns.append(FileOperationPattern(regex: #"ln\s+(?:-s\s+)?[^\s;|&]+\s+([^\s;|&]+)"#, type: .create, confidence: 0.80))
        
        // Directory operations that affect files
        patterns.append(FileOperationPattern(regex: #"mkdir\s+(?:-p\s+)?([^\s;|&]+)"#, type: .create, confidence: 0.70))
        patterns.append(FileOperationPattern(regex: #"rmdir\s+([^\s;|&]+)"#, type: .delete, confidence: 0.90))
        
        // Archive operations
        patterns.append(FileOperationPattern(regex: #"tar\s+.*[xf].*\s+([^\s;|&]+)"#, type: .create, confidence: 0.70))
        patterns.append(FileOperationPattern(regex: #"unzip\s+.*\s+([^\s;|&]+)"#, type: .create, confidence: 0.70))
        
        // Text editor patterns
        patterns.append(FileOperationPattern(regex: #"vim?\s+([^\s;|&]+)"#, type: .modify, confidence: 0.60))
        patterns.append(FileOperationPattern(regex: #"nano\s+([^\s;|&]+)"#, type: .modify, confidence: 0.60))
        patterns.append(FileOperationPattern(regex: #"emacs\s+([^\s;|&]+)"#, type: .modify, confidence: 0.60))
        
        return patterns
    }
    
    init() {
        self.operationPatterns = Self.createOperationPatterns()
        logger.info("BashFileOperationDetector initialized with \(operationPatterns.count) patterns", category: .fileTracking)
    }
    
    /// Predict file operations from a bash command
    func predictFileOperations(command: String, projectPath: URL) -> [FileOperationPrediction] {
        let startTime = CFAbsoluteTimeGetCurrent()
        var predictions: [FileOperationPrediction] = []
        
        // Clean up the command - remove comments and extra whitespace
        let cleanCommand = cleanCommand(command)
        
        // Apply each pattern to find potential file operations
        for pattern in operationPatterns {
            let matches = findMatches(in: cleanCommand, pattern: pattern)
            
            for match in matches {
                // Extract file path from the match
                let filePath = extractFilePath(from: match, projectPath: projectPath)
                
                if !filePath.isEmpty {
                    let prediction = FileOperationPrediction(
                        type: pattern.type,
                        filePath: filePath,
                        confidence: pattern.confidence
                    )
                    predictions.append(prediction)
                }
            }
        }
        
        // Remove duplicates and sort by confidence
        predictions = removeDuplicates(from: predictions)
        predictions.sort { $0.confidence > $1.confidence }
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.debug("⚡ Analyzed bash command in \(String(format: "%.1f", duration))ms - found \(predictions.count) potential operations", category: .fileTracking)
        
        return predictions
    }
    
    // MARK: - Private Methods
    
    private func cleanCommand(_ command: String) -> String {
        var cleaned = command
        
        // Remove comments (but preserve quoted strings)
        cleaned = removeComments(from: cleaned)
        
        // Normalize whitespace
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func removeComments(from command: String) -> String {
        // Simple comment removal that preserves quoted strings
        // This is a simplified approach - a full parser would be more robust
        var result = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false
        
        for char in command {
            if escaped {
                result.append(char)
                escaped = false
                continue
            }
            
            switch char {
            case "\\":
                escaped = true
                result.append(char)
            case "'":
                if !inDoubleQuote {
                    inSingleQuote.toggle()
                }
                result.append(char)
            case "\"":
                if !inSingleQuote {
                    inDoubleQuote.toggle()
                }
                result.append(char)
            case "#":
                if !inSingleQuote && !inDoubleQuote {
                    // Start of comment - ignore rest of line
                    if let newlineIndex = command[command.index(after: command.firstIndex(of: char)!)...].firstIndex(of: "\n") {
                        // Continue after newline
                        let restOfCommand = String(command[command.index(after: newlineIndex)...])
                        return result + "\n" + removeComments(from: restOfCommand)
                    } else {
                        // Comment goes to end of command
                        return result
                    }
                } else {
                    result.append(char)
                }
            default:
                result.append(char)
            }
        }
        
        return result
    }
    
    private func findMatches(in command: String, pattern: FileOperationPattern) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: pattern.regex, options: [.caseInsensitive])
            let range = NSRange(location: 0, length: command.utf16.count)
            let matches = regex.matches(in: command, options: [], range: range)
            
            return matches.compactMap { match in
                // Extract the captured group (file path)
                if match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    if let swiftRange = Range(range, in: command) {
                        return String(command[swiftRange])
                    }
                }
                return nil
            }
        } catch {
            logger.warning("Invalid regex pattern: \(pattern.regex)", category: .fileTracking)
            return []
        }
    }
    
    private func extractFilePath(from match: String, projectPath: URL) -> String {
        var filePath = match.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove quotes
        filePath = filePath.replacingOccurrences(of: "\"", with: "")
        filePath = filePath.replacingOccurrences(of: "'", with: "")
        
        // Handle wildcards and globs - for now, skip them
        if filePath.contains("*") || filePath.contains("?") || filePath.contains("[") {
            logger.debug("Skipping wildcard path: \(filePath)", category: .fileTracking)
            return ""
        }
        
        // Convert relative paths to project-relative
        if filePath.hasPrefix("/") {
            // Absolute path - check if it's within the project
            if filePath.hasPrefix(projectPath.path) {
                let relativePath = String(filePath.dropFirst(projectPath.path.count))
                return relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            } else {
                // Outside project - skip
                return ""
            }
        } else {
            // Relative path - use as is
            return filePath
        }
    }
    
    private func removeDuplicates(from predictions: [FileOperationPrediction]) -> [FileOperationPrediction] {
        var seen = Set<String>()
        var unique: [FileOperationPrediction] = []
        
        for prediction in predictions {
            let key = "\(prediction.type.rawValue):\(prediction.filePath)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(prediction)
            }
        }
        
        return unique
    }
}

// MARK: - Supporting Types

private struct FileOperationPattern {
    let regex: String
    let type: FileOperationType
    let confidence: Double // 0.0 to 1.0
}

