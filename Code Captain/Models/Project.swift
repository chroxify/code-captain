import Foundation

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let path: URL
    let gitWorktreePath: URL
    let providerType: ProviderType
    let createdAt: Date
    var lastAccessedAt: Date
    var sessions: [Session]
    var isActive: Bool
    
    init(name: String, path: URL, providerType: ProviderType = .claudeCode) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.gitWorktreePath = path.appendingPathComponent("CodeCaptain/workspace")
        self.providerType = providerType
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.sessions = []
        self.isActive = false
    }
    
    var displayName: String {
        name.isEmpty ? path.lastPathComponent : name
    }
    
    var processingSessions: [Session] {
        sessions.filter { $0.state == .processing }
    }
    
    var hasProcessingSessions: Bool {
        !processingSessions.isEmpty
    }
}

extension Project {
    static let mock = Project(
        name: "Sample Project",
        path: URL(fileURLWithPath: "/Users/dev/sample-project"),
        providerType: .claudeCode
    )
}