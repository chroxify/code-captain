import Foundation

/// Represents a CLI feature with version requirements and fallback behavior
struct FeatureRequirement {
    let minimumVersion: String
    let description: String
    let fallbackBehavior: (() -> [String])?
    
    init(minimumVersion: String, description: String, fallbackBehavior: (() -> [String])? = nil) {
        self.minimumVersion = minimumVersion
        self.description = description
        self.fallbackBehavior = fallbackBehavior
    }
}

/// Protocol for providers that support version-based feature checking
protocol VersionedProvider {
    /// Dictionary of feature names to their requirements
    var featureRequirements: [String: FeatureRequirement] { get }
    
    /// Check if a specific feature is supported by the current version
    func checkFeatureSupport(_ feature: String) async -> Bool
    
    /// Parse a version string into components
    func parseVersion(_ versionString: String) -> (major: Int, minor: Int, patch: Int)?
    
    /// Compare two versions (returns true if version1 >= version2)
    func compareVersions(_ version1: String, _ version2: String) -> Bool
}

/// Extension providing default implementations
extension VersionedProvider {
    func parseVersion(_ versionString: String) -> (major: Int, minor: Int, patch: Int)? {
        // Remove common prefixes and clean the version string
        let cleanVersion = versionString
            .replacingOccurrences(of: "v", with: "")
            .replacingOccurrences(of: "claude-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let versionComponents = cleanVersion.components(separatedBy: ".")
        guard versionComponents.count >= 3,
              let major = Int(versionComponents[0]),
              let minor = Int(versionComponents[1]),
              let patch = Int(versionComponents[2]) else {
            return nil
        }
        
        return (major: major, minor: minor, patch: patch)
    }
    
    func compareVersions(_ version1: String, _ version2: String) -> Bool {
        guard let v1 = parseVersion(version1),
              let v2 = parseVersion(version2) else {
            return false
        }
        
        if v1.major != v2.major {
            return v1.major > v2.major
        }
        
        if v1.minor != v2.minor {
            return v1.minor > v2.minor
        }
        
        return v1.patch >= v2.patch
    }
    
    func checkFeatureSupport(_ feature: String) async -> Bool {
        guard let requirement = featureRequirements[feature] else {
            return false // Feature not recognized
        }
        
        // This method should be called on a type that conforms to both protocols
        // The implementation will be provided by the conforming type
        if let versionProvider = self as? VersionProvider {
            guard let currentVersion = await versionProvider.getCurrentVersion() else {
                return false // Can't determine version, assume not supported
            }
            
            return compareVersions(currentVersion, requirement.minimumVersion)
        }
        
        return false
    }
}

/// Helper protocol to get current version (should be implemented by conforming types)
protocol VersionProvider {
    func getCurrentVersion() async -> String?
}

/// Feature-aware CLI argument builder
class FeatureAwareCLIBuilder {
    private let provider: VersionedProvider & VersionProvider
    private var arguments: [String] = []
    
    init(provider: VersionedProvider & VersionProvider) {
        self.provider = provider
    }
    
    /// Add arguments for a feature, with automatic fallback if not supported
    func addFeature(_ featureName: String, arguments: [String]) async -> FeatureAwareCLIBuilder {
        let isSupported = await provider.checkFeatureSupport(featureName)
        
        if isSupported {
            self.arguments.append(contentsOf: arguments)
        } else if let requirement = provider.featureRequirements[featureName],
                  let fallback = requirement.fallbackBehavior {
            self.arguments.append(contentsOf: fallback())
        }
        
        return self
    }
    
    /// Add regular arguments (always included)
    func addArguments(_ args: [String]) -> FeatureAwareCLIBuilder {
        self.arguments.append(contentsOf: args)
        return self
    }
    
    /// Build the final arguments array
    func build() -> [String] {
        return arguments
    }
    
    /// Reset the builder for reuse
    func reset() -> FeatureAwareCLIBuilder {
        arguments.removeAll()
        return self
    }
}

/// Predefined Claude Code features
enum ClaudeCodeFeature {
    static let sessionId = "session-id"
    static let streamJSON = "stream-json"
    static let verbose = "verbose"
    static let resume = "resume"
    
    /// Get all Claude Code feature definitions
    static func getAllFeatures() -> [String: FeatureRequirement] {
        return [
            sessionId: FeatureRequirement(
                minimumVersion: "1.0.53",
                description: "Support for --session-id flag for session management",
                fallbackBehavior: {
                    // Fallback to --resume flag for older versions
                    return []  // Will be handled specifically in session logic
                }
            ),
            streamJSON: FeatureRequirement(
                minimumVersion: "1.0.0", // Assuming this was available early
                description: "Support for --output-format stream-json"
            ),
            verbose: FeatureRequirement(
                minimumVersion: "1.0.0", // Assuming this was available early
                description: "Support for --verbose flag"
            ),
            resume: FeatureRequirement(
                minimumVersion: "0.9.0", // Assuming this was available in older versions
                description: "Support for --resume flag for session resumption"
            )
        ]
    }
}