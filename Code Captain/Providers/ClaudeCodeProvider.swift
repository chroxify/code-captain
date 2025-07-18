import Foundation
import Combine

class ClaudeCodeProvider: CodeAssistantProvider {
    private let logger = Logger.shared
    private let processQueue = DispatchQueue(label: "com.codecaptain.claude", qos: .userInitiated)
    private var cachedVersion: String?
    
    // MARK: - VersionedProvider Implementation
    
    lazy var featureRequirements: [String: FeatureRequirement] = ClaudeCodeFeature.getAllFeatures()
    
    func getCurrentVersion() async -> String? {
        return await checkClaudeCodeVersion()
    }
    
    // MARK: - CodeAssistantProvider Protocol
    
    let name = "Claude Code"
    private let _version = "1.0.0"
    
    var version: String {
        return cachedVersion ?? _version
    }
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
        // Always use fallback behavior - return a placeholder that indicates we need to create the session on first message
        let placeholderSessionId = "pending-" + UUID().uuidString.lowercased()
        logger.info("Created placeholder Claude Code session with ID: \(placeholderSessionId) (using legacy fallback session creation)", category: .provider)
        return placeholderSessionId
    }
    
    /// Check Claude Code version and cache it
    func checkClaudeCodeVersion() async -> String? {
        if let cached = cachedVersion {
            return cached
        }
        
        do {
            let process = Process()
            let (executable, baseArgs) = try getClaudeExecutableAndArguments()
            process.executableURL = URL(fileURLWithPath: executable)
            
            var arguments = baseArgs
            arguments.append("--version")
            process.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 && !output.isEmpty {
                let versionString = output.trimmingCharacters(in: .whitespacesAndNewlines)
                cachedVersion = versionString
                logger.info("Claude Code version detected: \(versionString)", category: .provider)
                return versionString
            } else {
                logger.error("Failed to get Claude Code version - Status: \(process.terminationStatus), Error: \(error)", category: .provider)
            }
        } catch {
            logger.error("Failed to check Claude Code version: \(error)", category: .provider)
        }
        
        return nil
    }
    
    /// Check if Claude Code version supports --session-id flag (>= 1.0.53)
    private func supportsSessionIdFlag() async -> Bool {
        return await checkFeatureSupport(ClaudeCodeFeature.sessionId)
    }
    
    /// Check if a session ID is a placeholder that needs real session creation
    private func isPlaceholderSessionId(_ sessionId: String?) -> Bool {
        return sessionId?.hasPrefix("pending-") == true
    }
    
    /// Extract actual session ID from Claude Code response for fallback sessions
    private func extractSessionIdFromResponse(_ messages: [SDKMessage]) -> String? {
        // Look for the session ID in any of the response messages
        for message in messages {
            let sessionId = message.sessionId
            if !sessionId.isEmpty {
                return sessionId
            }
        }
        return nil
    }
    
    /// Send a message to Claude Code and get streaming response
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
                    
                    // Build arguments for Claude CLI using streaming SDK approach
                    var arguments = baseArgs
                    
                    // Use print mode for non-interactive message sending with streaming
                    arguments.append("-p")
                    arguments.append("--output-format")
                    arguments.append("stream-json")
                    arguments.append("--verbose")
                    
                    // Determine session handling strategy (using legacy fallback behavior only)
                    if let sessionId = sessionId {
                        if self.isPlaceholderSessionId(sessionId) {
                            // For placeholder session ID, start fresh session without any session flags
                            self.logger.info("sendMessage: Starting new Claude Code session for placeholder ID: \(sessionId) (legacy fallback behavior)", category: .provider)
                        } else {
                            // For real session ID, always use --resume
                            arguments.append("--resume")
                            arguments.append(sessionId)
                            self.logger.info("sendMessage: Resuming Claude Code session ID: \(sessionId) (--resume flag)", category: .provider)
                        }
                    } else {
                        self.logger.info("sendMessage: Starting new Claude Code session (no session ID provided)", category: .provider)
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
                    
                    // Set up streaming output reading with FileHandle notifications
                    let outputHandle = outputPipe.fileHandleForReading
                    let errorHandle = errorPipe.fileHandleForReading
                    
                    var allMessages: [SDKMessage] = []
                    var finalContent = ""
                    var sessionId: String?
                    var metadata: [String: Any] = [:]
                    var outputBuffer = Data()
                    
                    // Create a semaphore to coordinate reading
                    let semaphore = DispatchSemaphore(value: 0)
                    var isCompleted = false
                    
                    // Set up notification-based reading for real-time streaming
                    let notificationCenter = NotificationCenter.default
                    
                    let dataAvailableObserver = notificationCenter.addObserver(
                        forName: .NSFileHandleDataAvailable,
                        object: outputHandle,
                        queue: nil
                    ) { _ in
                        let availableData = outputHandle.availableData
                        if !availableData.isEmpty {
                            outputBuffer.append(availableData)
                            
                            // Process complete lines
                            while let newlineRange = outputBuffer.range(of: Data([0x0A])) { // \n
                                let lineData = outputBuffer.subdata(in: 0..<newlineRange.lowerBound)
                                outputBuffer = outputBuffer.subdata(in: newlineRange.upperBound..<outputBuffer.count)
                                
                                // Try to parse this line as JSON
                                if let jsonString = String(data: lineData, encoding: .utf8),
                                   !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    
                                    self.logger.debug("Streaming line: \(jsonString)", category: .provider)
                                    
                                    // Try to parse as SDKMessage with enhanced error recovery
                                    if let lineJsonData = jsonString.data(using: .utf8) {
                                        do {
                                            let sdkMessage = try self.parseSDKMessageWithRecovery(from: lineJsonData)
                                            allMessages.append(sdkMessage)
                                            
                                            // Extract session ID from first message that has one
                                            if sessionId == nil {
                                                sessionId = sdkMessage.sessionId
                                            }
                                            
                                            // Build content from assistant messages
                                            if case .assistant(let assistantMsg) = sdkMessage {
                                                let textContent = assistantMsg.message.content.compactMap { contentBlock in
                                                    switch contentBlock {
                                                    case .text(let textBlock):
                                                        return textBlock.text
                                                    case .thinking(let thinkingBlock):
                                                        return thinkingBlock.thinking
                                                    default:
                                                        return nil
                                                    }
                                                }.joined(separator: "\n")
                                                
                                                if !textContent.isEmpty {
                                                    finalContent += textContent + "\n"
                                                }
                                            }
                                            
                                            self.logger.debug("Parsed streaming message: \(sdkMessage.id)", category: .provider)
                                            
                                        } catch {
                                            // Enhanced fallback parsing
                                            if let fallbackMessage = self.parseWithFallback(jsonString: jsonString, error: error) {
                                                allMessages.append(fallbackMessage)
                                                
                                                if sessionId == nil {
                                                    sessionId = fallbackMessage.sessionId
                                                }
                                                
                                                // Add fallback content
                                                if case .assistant(let assistantMsg) = fallbackMessage {
                                                    let textContent = assistantMsg.message.content.compactMap { contentBlock in
                                                        switch contentBlock {
                                                        case .text(let textBlock):
                                                            return textBlock.text
                                                        default:
                                                            return nil
                                                        }
                                                    }.joined(separator: "\n")
                                                    
                                                    if !textContent.isEmpty {
                                                        finalContent += textContent + "\n"
                                                    }
                                                }
                                            }
                                            
                                            self.logger.debug("Used fallback parsing for line: \(error.localizedDescription)", category: .provider)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Continue reading if process is still running
                        if process.isRunning {
                            outputHandle.waitForDataInBackgroundAndNotify()
                        }
                    }
                    
                    // Start reading
                    outputHandle.waitForDataInBackgroundAndNotify()
                    
                    // Wait for completion in background
                    DispatchQueue.global(qos: .background).async {
                        process.waitUntilExit()
                        isCompleted = true
                        semaphore.signal()
                    }
                    
                    // Wait for process completion
                    semaphore.wait()
                    
                    // Clean up observer
                    notificationCenter.removeObserver(dataAvailableObserver)
                    
                    // Process any remaining buffer
                    if !outputBuffer.isEmpty {
                        if let remainingString = String(data: outputBuffer, encoding: .utf8),
                           !remainingString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            
                            // Try to parse remaining data
                            if let remainingData = remainingString.data(using: .utf8) {
                                do {
                                    let sdkMessage = try JSONDecoder().decode(SDKMessage.self, from: remainingData)
                                    allMessages.append(sdkMessage)
                                    
                                    if sessionId == nil {
                                        sessionId = sdkMessage.sessionId
                                    }
                                } catch {
                                    // Ignore parsing errors for remaining data
                                }
                            }
                        }
                    }
                    
                    if process.terminationStatus == 0 {
                        let response = ClaudeStreamingResponse(
                            content: finalContent.trimmingCharacters(in: .whitespacesAndNewlines),
                            sessionId: sessionId,
                            metadata: metadata.isEmpty ? nil : metadata,
                            messages: allMessages
                        )
                        
                        let providerResponse = ProviderResponse(
                            content: response.content,
                            sessionId: response.sessionId,
                            metadata: response.metadata,
                            messages: response.messages
                        )
                        continuation.resume(returning: providerResponse)
                    } else {
                        // Handle error
                        let errorData = errorHandle.readDataToEndOfFile()
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
    
    /// Send a message to Claude Code and get streaming response via AsyncStream
    func sendMessageStream(
        _ message: String,
        workingDirectory: URL,
        sessionId: String? = nil
    ) -> AsyncStream<SDKMessage> {
        return AsyncStream { continuation in
            Task {
                do {
                    let process = Process()
                    process.currentDirectoryURL = workingDirectory
                    
                    // Get Claude executable and arguments
                    let (executable, baseArgs) = try self.getClaudeExecutableAndArguments()
                    process.executableURL = URL(fileURLWithPath: executable)
                    
                    // Build arguments for Claude CLI using streaming SDK approach
                    var arguments = baseArgs
                    
                    // Use print mode for non-interactive message sending with streaming
                    arguments.append("-p")
                    arguments.append("--output-format")
                    arguments.append("stream-json")
                    arguments.append("--verbose")
                    
                    // Determine session handling strategy (using legacy fallback behavior only)
                    if let sessionId = sessionId {
                        if self.isPlaceholderSessionId(sessionId) {
                            // For placeholder session ID, start fresh session without any session flags
                            self.logger.info("sendMessageStream: Starting new Claude Code session for placeholder ID: \(sessionId) (legacy fallback behavior)", category: .provider)
                        } else {
                            // For real session ID, always use --resume
                            arguments.append("--resume")
                            arguments.append(sessionId)
                            self.logger.info("sendMessageStream: Resuming Claude Code session ID: \(sessionId) (--resume flag)", category: .provider)
                        }
                    } else {
                        self.logger.info("sendMessageStream: Starting new Claude Code session (no session ID provided)", category: .provider)
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
                    
                    // Set up streaming output reading
                    let outputHandle = outputPipe.fileHandleForReading
                    var outputBuffer = Data()
                    
                    // Create a task to read streaming output
                    let streamingTask = Task {
                        while process.isRunning {
                            let availableData = outputHandle.availableData
                            if !availableData.isEmpty {
                                outputBuffer.append(availableData)
                                
                                // Process complete lines
                                while let newlineRange = outputBuffer.range(of: Data([0x0A])) { // \n
                                    let lineData = outputBuffer.subdata(in: 0..<newlineRange.lowerBound)
                                    outputBuffer = outputBuffer.subdata(in: newlineRange.upperBound..<outputBuffer.count)
                                    
                                    // Try to parse this line as JSON
                                    if let jsonString = String(data: lineData, encoding: .utf8),
                                       !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        
                                        self.logger.debug("Streaming line: \(jsonString)", category: .provider)
                                        
                                        // Try to parse as SDKMessage with enhanced error recovery
                                        if let lineJsonData = jsonString.data(using: .utf8) {
                                            do {
                                                let sdkMessage = try self.parseSDKMessageWithRecovery(from: lineJsonData)
                                                self.logger.debug("Yielding streaming message: \(sdkMessage.id)", category: .provider)
                                                continuation.yield(sdkMessage)
                                            } catch {
                                                // Enhanced fallback parsing
                                                if let fallbackMessage = self.parseWithFallback(jsonString: jsonString, error: error) {
                                                    self.logger.debug("Yielding fallback streaming message: \(fallbackMessage.id)", category: .provider)
                                                    continuation.yield(fallbackMessage)
                                                } else {
                                                    self.logger.debug("Failed to parse streaming message: \(error)", category: .provider)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Small delay to prevent busy waiting
                            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                        }
                        
                        // Process any remaining buffer
                        if !outputBuffer.isEmpty {
                            if let remainingString = String(data: outputBuffer, encoding: .utf8),
                               !remainingString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                
                                // Try to parse remaining data
                                if let remainingData = remainingString.data(using: .utf8) {
                                    do {
                                        let sdkMessage = try JSONDecoder().decode(SDKMessage.self, from: remainingData)
                                        self.logger.debug("Yielding final streaming message: \(sdkMessage.id)", category: .provider)
                                        continuation.yield(sdkMessage)
                                    } catch {
                                        // Ignore parsing errors for remaining data
                                    }
                                }
                            }
                        }
                        
                        // Wait for process completion
                        process.waitUntilExit()
                        
                        if process.terminationStatus != 0 {
                            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                            self.logger.error("Claude Code execution failed: \(errorMessage)", category: .provider)
                        }
                        
                        continuation.finish()
                    }
                    
                    // Handle cancellation
                    continuation.onTermination = { @Sendable _ in
                        streamingTask.cancel()
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                    
                } catch {
                    self.logger.error("Failed to start Claude Code process: \(error)", category: .provider)
                    continuation.finish()
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
    
    private func parseStreamingClaudeResponse(from data: Data) throws -> ClaudeStreamingResponse {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ClaudeCodeError.invalidResponse("Could not decode response as UTF-8")
        }
        
        logger.debug("Raw Claude streaming response: \(jsonString)", category: .provider)
        
        // Split by newlines to get individual JSON messages
        let lines = jsonString.components(separatedBy: .newlines)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        
        var messages: [SDKMessage] = []
        var finalContent = ""
        var sessionId: String?
        var metadata: [String: Any] = [:]
        
        for line in lines {
            guard let lineData = line.data(using: .utf8) else { continue }
            
            do {
                // Try to parse as SDKMessage
                let sdkMessage = try JSONDecoder().decode(SDKMessage.self, from: lineData)
                messages.append(sdkMessage)
                
                // Extract session ID from first message that has one
                if sessionId == nil {
                    sessionId = sdkMessage.sessionId
                }
                
                // Build content from assistant messages
                if case .assistant(let assistantMsg) = sdkMessage {
                    let textContent = assistantMsg.message.content.compactMap { contentBlock in
                        switch contentBlock {
                        case .text(let textBlock):
                            return textBlock.text
                        case .thinking(let thinkingBlock):
                            return thinkingBlock.thinking
                        default:
                            return nil
                        }
                    }.joined(separator: "\n")
                    
                    if !textContent.isEmpty {
                        finalContent += textContent + "\n"
                    }
                }
                
            } catch {
                // If it's not a valid SDKMessage, try to parse as legacy format
                if let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {
                    // Extract legacy fields
                    if let content = json["result"] as? String ?? json["content"] as? String {
                        finalContent += content + "\n"
                    }
                    
                    if let legacySessionId = json["session_id"] as? String ?? json["sessionId"] as? String {
                        sessionId = legacySessionId
                    }
                    
                    // Merge metadata
                    for (key, value) in json {
                        metadata[key] = value
                    }
                }
            }
        }
        
        return ClaudeStreamingResponse(
            content: finalContent.trimmingCharacters(in: .whitespacesAndNewlines),
            sessionId: sessionId,
            metadata: metadata.isEmpty ? nil : metadata,
            messages: messages
        )
    }
    
    // MARK: - Enhanced JSON Parsing with Error Recovery
    
    private func parseSDKMessageWithRecovery(from data: Data) throws -> SDKMessage {
        // First, try standard JSON decoding
        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(SDKMessage.self, from: data)
            
            // Post-process to fix Claude Code CLI specific issues
            return fixClaudeCodeSpecificIssues(message: message)
        } catch {
            // If standard decoding fails, try to fix common JSON issues
            if let fixedData = tryFixCommonJSONIssues(data: data) {
                do {
                    let decoder = JSONDecoder()
                    let message = try decoder.decode(SDKMessage.self, from: fixedData)
                    
                    // Post-process to fix Claude Code CLI specific issues
                    return fixClaudeCodeSpecificIssues(message: message)
                } catch {
                    // If still fails, throw the original error
                    throw error
                }
            } else {
                throw error
            }
        }
    }
    
    /// Fix Claude Code CLI specific issues like tool results being labeled as user messages
    private func fixClaudeCodeSpecificIssues(message: SDKMessage) -> SDKMessage {
        // Don't modify the message structure - just return it as-is
        // The role override will be handled in the Message model's displayRole property
        return message
    }
    
    private func tryFixCommonJSONIssues(data: Data) -> Data? {
        guard let jsonString = String(data: data, encoding: .utf8) else { return nil }
        
        var fixedString = jsonString
        
        // Fix common JSON issues
        // 1. Remove trailing commas
        fixedString = fixedString.replacingOccurrences(of: ",\\s*}", with: "}", options: .regularExpression)
        fixedString = fixedString.replacingOccurrences(of: ",\\s*]", with: "]", options: .regularExpression)
        
        // 2. Fix unescaped quotes in strings
        fixedString = fixedString.replacingOccurrences(of: "\"([^\"]*?)\"([^\"]*?)\"", with: "\"$1\\\"$2\"", options: .regularExpression)
        
        // 3. Fix missing quotes around keys
        fixedString = fixedString.replacingOccurrences(of: "([{,])\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*:", with: "$1\"$2\":", options: .regularExpression)
        
        // 4. Fix incomplete objects/arrays
        if fixedString.filter({ $0 == "{" }).count > fixedString.filter({ $0 == "}" }).count {
            fixedString += "}"
        }
        if fixedString.filter({ $0 == "[" }).count > fixedString.filter({ $0 == "]" }).count {
            fixedString += "]"
        }
        
        return fixedString.data(using: .utf8)
    }
    
    private func parseWithFallback(jsonString: String, error: Error) -> SDKMessage? {
        // Try to parse as legacy format first
        if let jsonData = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            let sessionId = json["session_id"] as? String ?? json["sessionId"] as? String ?? "unknown"
            
            // Try to determine message type from content
            if let content = json["result"] as? String ?? json["content"] as? String {
                // Create a fallback assistant message
                let textBlock = TextBlock(text: content)
                let anthropicMessage = AnthropicMessage(
                    id: UUID().uuidString,
                    content: [.text(textBlock)],
                    model: json["model"] as? String,
                    role: "assistant",
                    stop_reason: nil,
                    stop_sequence: nil,
                    usage: nil
                )
                
                let assistantMessage = AssistantMessage(
                    message: anthropicMessage,
                    session_id: sessionId,
                    parent_tool_use_id: nil
                )
                
                return .assistant(assistantMessage)
            }
            
            // If no content, create a system message about the parsing error
            let systemMessage = SystemMessage(
                subtype: .initMessage,
                session_id: sessionId,
                apiKeySource: nil,
                cwd: nil,
                tools: nil,
                mcp_servers: nil,
                model: nil,
                permissionMode: nil
            )
            
            return .system(systemMessage)
        }
        
        // Final fallback: create an error message
        let errorText = "Failed to parse streaming message: \(error.localizedDescription)"
        let textBlock = TextBlock(text: errorText)
        let anthropicMessage = AnthropicMessage(
            id: UUID().uuidString,
            content: [.text(textBlock)],
            model: nil,
            role: "assistant",
            stop_reason: nil,
            stop_sequence: nil,
            usage: nil
        )
        
        let assistantMessage = AssistantMessage(
            message: anthropicMessage,
            session_id: "unknown",
            parent_tool_use_id: nil
        )
        
        return .assistant(assistantMessage)
    }
}

// MARK: - Data Models

struct ClaudeResponse {
    let content: String
    let sessionId: String?
    let metadata: [String: Any]?
}

struct ClaudeStreamingResponse {
    let content: String
    let sessionId: String?
    let metadata: [String: Any]?
    let messages: [SDKMessage]
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