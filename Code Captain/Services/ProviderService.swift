import Foundation
import Combine

class ProviderService: ObservableObject {
    private let logger = Logger.shared
    private var providers: [ProviderType: CodeAssistantProvider] = [:]
    
    init() {
        setupProviders()
    }
    
    // MARK: - Provider Management
    
    private func setupProviders() {
        // Register Claude Code provider
        let claudeCodeProvider = ClaudeCodeProvider()
        providers[.claudeCode] = claudeCodeProvider
        
        // Future: Register other providers here
        // providers[.openCode] = OpenCodeProvider()
        // providers[.custom] = CustomProvider()
        
        logger.info("Provider service initialized with \(providers.count) providers", category: .provider)
    }
    
    func getProvider(for type: ProviderType) -> CodeAssistantProvider? {
        return providers[type]
    }
    
    func isProviderAvailable(_ type: ProviderType) -> Bool {
        return providers[type]?.isAvailable ?? false
    }
    
    func getAvailableProviders() -> [ProviderType] {
        return providers.compactMap { (type, provider) in
            provider.isAvailable ? type : nil
        }
    }
    
    // MARK: - Session Management
    
    /// Create a new session using the specified provider
    func createSession(using providerType: ProviderType, in workingDirectory: URL) async throws -> String {
        guard let provider = providers[providerType] else {
            throw ProviderError.providerNotFound(providerType)
        }
        
        guard provider.isAvailable else {
            throw ProviderError.providerNotAvailable(providerType)
        }
        
        logger.info("Creating session with provider: \(providerType.displayName)", category: .provider)
        
        do {
            let sessionId = try await provider.createSession(in: workingDirectory)
            logger.info("Session created successfully with ID: \(sessionId)", category: .provider)
            return sessionId
        } catch {
            logger.error("Failed to create session with provider \(providerType.displayName): \(error)", category: .provider)
            throw error
        }
    }
    
    /// Send a message using the specified provider
    func sendMessage(
        _ message: String,
        using providerType: ProviderType,
        workingDirectory: URL,
        sessionId: String? = nil
    ) async throws -> ProviderResponse {
        guard let provider = providers[providerType] else {
            throw ProviderError.providerNotFound(providerType)
        }
        
        guard provider.isAvailable else {
            throw ProviderError.providerNotAvailable(providerType)
        }
        
        logger.info("Sending message with provider: \(providerType.displayName)", category: .provider)
        
        do {
            let response = try await provider.sendMessage(message, workingDirectory: workingDirectory, sessionId: sessionId)
            logger.info("Message sent successfully", category: .provider)
            return response
        } catch {
            logger.error("Failed to send message with provider \(providerType.displayName): \(error)", category: .provider)
            throw error
        }
    }
    
    /// List available sessions from the specified provider
    func listSessions(using providerType: ProviderType) async throws -> [ProviderSession] {
        guard let provider = providers[providerType] else {
            throw ProviderError.providerNotFound(providerType)
        }
        
        guard provider.isAvailable else {
            throw ProviderError.providerNotAvailable(providerType)
        }
        
        logger.info("Listing sessions with provider: \(providerType.displayName)", category: .provider)
        
        do {
            let sessions = try await provider.listSessions()
            logger.info("Listed \(sessions.count) sessions", category: .provider)
            return sessions
        } catch {
            logger.error("Failed to list sessions with provider \(providerType.displayName): \(error)", category: .provider)
            throw error
        }
    }
}

// MARK: - Errors

enum ProviderError: LocalizedError {
    case providerNotFound(ProviderType)
    case providerNotAvailable(ProviderType)
    case invalidConfiguration
    case communicationFailed
    
    var errorDescription: String? {
        switch self {
        case .providerNotFound(let type):
            return "Provider not found: \(type.displayName)"
        case .providerNotAvailable(let type):
            return "Provider not available: \(type.displayName)"
        case .invalidConfiguration:
            return "Invalid provider configuration"
        case .communicationFailed:
            return "Communication with provider failed"
        }
    }
}