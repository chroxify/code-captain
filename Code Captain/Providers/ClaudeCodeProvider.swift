import Foundation
import Combine

class ClaudeCodeProvider: CodeAssistantProvider {
    private let logger = Logger.shared
    private let processQueue = DispatchQueue(label: "com.codecaptain.claude", qos: .userInitiated)
    
    // MARK: - CodeAssistantProvider Protocol
    
    let name = "Claude Code"
    let version = "1.0.0"
    let supportedFeatures: Set<ProviderFeature> = [
        .fileOperations,
        .gitIntegration,
        .codeExecution,
        .streaming
    ]
    
    var isAvailable: Bool {
        return getClaudeCodeExecutablePath() != nil
    }
    
    // MARK: - Session Management
    
    /// Create a new Claude Code session and return the session ID
    func createSession(in workingDirectory: URL) async throws -> String {
        logger.info("Creating new Claude Code session in: \(workingDirectory.path)", category: .provider)
        
        // Start a new session by sending an initial message
        let response = try await sendMessage(
            "Hello! I'm starting a new coding session.",
            workingDirectory: workingDirectory,
            sessionId: nil
        )
        
        // Extract session ID from Claude Code's response
        guard let sessionId = response.sessionId else {
            throw ClaudeCodeError.invalidResponse("No session ID returned from Claude Code")
        }
        
        logger.info("Created new session with ID: \(sessionId)", category: .provider)
        return sessionId
    }
    
    /// Send a message to Claude Code and get response
    func sendMessage(
        _ message: String,
        workingDirectory: URL,
        sessionId: String? = nil
    ) async throws -> ProviderResponse {
        logger.info("Sending message to Claude Code: \(message)", category: .provider)
        
        return try await withCheckedThrowingContinuation { continuation in
            processQueue.async {
                do {
                    let process = Process()
                    process.currentDirectoryURL = workingDirectory
                    
                    // Get Claude executable and arguments
                    let (executable, baseArgs) = try self.getClaudeExecutableAndArguments()
                    process.executableURL = URL(fileURLWithPath: executable)
                    
                    // Build arguments for Claude CLI using SDK approach
                    var arguments = baseArgs
                    
                    // Use print mode for non-interactive message sending
                    arguments.append("-p")
                    arguments.append("--output-format")
                    arguments.append("json")
                    
                    // If we have a session ID, resume it
                    if let sessionId = sessionId {
                        arguments.append("--resume")
                        arguments.append(sessionId)
                    }
                    
                    // Add the message as the final argument
                    arguments.append(message)
                    
                    process.arguments = arguments
                    
                    // Set up environment
                    var environment = Foundation.ProcessInfo.processInfo.environment
                    environment["TERM"] = "xterm-256color"
                    environment["FORCE_COLOR"] = "1"
                    environment["NODE_NO_WARNINGS"] = "1"
                    process.environment = environment
                    
                    // Set up pipes
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    
                    // Start the process
                    try process.run()
                    
                    // Wait for completion
                    process.waitUntilExit()
                    
                    // Read output
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    if process.terminationStatus == 0 {
                        // Parse successful response
                        let response = try self.parseClaudeResponse(from: outputData)
                        let providerResponse = ProviderResponse(
                            content: response.content,
                            sessionId: response.sessionId,
                            metadata: response.metadata
                        )
                        continuation.resume(returning: providerResponse)
                    } else {
                        // Handle error
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        self.logger.error("Claude Code execution failed: \(errorMessage)", category: .provider)
                        throw ClaudeCodeError.executionFailed(errorMessage)
                    }
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// List all available Claude Code sessions
    func listSessions() async throws -> [ProviderSession] {
        logger.info("Listing Claude Code sessions", category: .provider)
        
        return try await withCheckedThrowingContinuation { continuation in
            processQueue.async {
                do {
                    let process = Process()
                    
                    // Get Claude executable and arguments
                    let (executable, baseArgs) = try self.getClaudeExecutableAndArguments()
                    process.executableURL = URL(fileURLWithPath: executable)
                    
                    var arguments = baseArgs
                    arguments.append("--list-sessions") // Use SDK command to list sessions
                    
                    process.arguments = arguments
                    
                    // Set up environment
                    var environment = Foundation.ProcessInfo.processInfo.environment
                    environment["TERM"] = "xterm-256color"
                    environment["NODE_NO_WARNINGS"] = "1"
                    process.environment = environment
                    
                    // Set up pipes
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    
                    // Start the process
                    try process.run()
                    
                    // Wait for completion
                    process.waitUntilExit()
                    
                    // For now, return empty array since we need to parse Claude's session list format
                    // This would need to be implemented based on Claude's actual output format
                    let providerSessions: [ProviderSession] = []
                    continuation.resume(returning: providerSessions)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Claude CLI Discovery
    
    private func getClaudeExecutableAndArguments() throws -> (executable: String, arguments: [String]) {
        guard let claudePath = getClaudeCodeExecutablePath() else {
            throw ClaudeCodeError.executionFailed("Claude Code CLI not found")
        }
        
        return try buildExecutableAndArguments(claudePath: claudePath)
    }
    
    private func getClaudeCodeExecutablePath() -> String? {
        // Check for Bun-installed Claude Code first
        let bunPath = "/Users/\(NSUserName())/.bun/bin/claude"
        
        if FileManager.default.fileExists(atPath: bunPath) {
            // Check file attributes to handle symlinks properly
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: bunPath)
                
                // Check if it's a symlink
                if let fileType = attributes[.type] as? FileAttributeType, fileType == .typeSymbolicLink {
                    let destinationPath = try FileManager.default.destinationOfSymbolicLink(atPath: bunPath)
                    
                    // If it's a JavaScript file, we need to run it through node
                    if destinationPath.hasSuffix(".js") {
                        return bunPath
                    }
                }
                
                // Check standard executable permissions
                if FileManager.default.isExecutableFile(atPath: bunPath) {
                    return bunPath
                }
            } catch {
                // Continue to other paths
            }
        }
        
        // Check other common installation paths
        let possiblePaths = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Try to find Claude Code using 'which' command as fallback
        return findClaudeCodePath()
    }
    
    private func findClaudeCodePath() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "claude"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return path
                }
            }
        } catch {
            // Fall back to nil
        }
        
        return nil
    }
    
    private func buildExecutableAndArguments(claudePath: String) throws -> (executable: String, arguments: [String]) {
        // Check if this is a Bun/npm-installed Claude Code (symlink to .js file)
        if FileManager.default.fileExists(atPath: claudePath) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: claudePath)
                if let fileType = attributes[.type] as? FileAttributeType, fileType == .typeSymbolicLink {
                    let destinationPath = try FileManager.default.destinationOfSymbolicLink(atPath: claudePath)
                    
                    if destinationPath.hasSuffix(".js") {
                        // This is a JavaScript file, we need to run it through node
                        guard let nodeExecutable = findNodeExecutable() else {
                            throw ClaudeCodeError.executionFailed("Node.js not found. Claude Code requires Node.js to run.")
                        }
                        
                        // Resolve the full path to the JavaScript file
                        let claudeDir = URL(fileURLWithPath: claudePath).deletingLastPathComponent()
                        let fullJSPath = claudeDir.appendingPathComponent(destinationPath).standardized.path
                        
                        return (executable: nodeExecutable, arguments: [fullJSPath])
                    }
                }
            } catch {
                // Continue with regular executable approach
            }
        }
        
        // For regular executable
        return (executable: claudePath, arguments: [])
    }
    
    private func findNodeExecutable() -> String? {
        // First try common system paths
        let systemPaths = [
            "/usr/bin/node",
            "/usr/local/bin/node",
            "/opt/homebrew/bin/node"
        ]
        
        for path in systemPaths {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Try to find node using 'which' command with proper PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "node"]
        
        // Set up environment with common paths
        var environment = Foundation.ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/Users/\(NSUserName())/.local/share/nvm/v20.18.1/bin",
            "/Users/\(NSUserName())/.nvm/versions/node/v20.18.1/bin",
            "/Users/\(NSUserName())/.volta/bin",
            "/Users/\(NSUserName())/.bun/bin"
        ]
        
        let currentPath = environment["PATH"] ?? ""
        let newPath = (additionalPaths + [currentPath]).joined(separator: ":")
        environment["PATH"] = newPath
        process.environment = environment
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return path
                }
            }
        } catch {
            // Fall back to nil
        }
        
        return nil
    }
    
    // MARK: - Response Parsing
    
    private func parseClaudeResponse(from data: Data) throws -> ClaudeResponse {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ClaudeCodeError.invalidResponse("Could not decode response as UTF-8")
        }
        
        logger.debug("Raw Claude response: \(jsonString)", category: .provider)
        
        // Try to parse as JSON first
        if let jsonData = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            // Extract content from the "result" field (Claude Code's response format)
            let content = json["result"] as? String ?? json["content"] as? String ?? jsonString
            
            // Extract session ID from the "session_id" field (Claude Code's response format)
            let sessionId = json["session_id"] as? String ?? json["sessionId"] as? String
            
            // Check if this is an error response
            let isError = json["is_error"] as? Bool ?? false
            if isError {
                throw ClaudeCodeError.executionFailed(content)
            }
            
            return ClaudeResponse(
                content: content,
                sessionId: sessionId,
                metadata: json
            )
        } else {
            // Fall back to treating the entire response as content
            return ClaudeResponse(
                content: jsonString,
                sessionId: nil,
                metadata: nil
            )
        }
    }
}

// MARK: - Data Models

struct ClaudeResponse {
    let content: String
    let sessionId: String?
    let metadata: [String: Any]?
}

struct ClaudeSession {
    let id: String
    let name: String
    let lastUsed: Date
    let messageCount: Int
}

// MARK: - Errors

enum ClaudeCodeError: LocalizedError {
    case executionFailed(String)
    case invalidResponse(String)
    case sessionNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Claude Code execution failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from Claude Code: \(message)"
        case .sessionNotFound(let sessionId):
            return "Session not found: \(sessionId)"
        }
    }
}