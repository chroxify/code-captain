import Foundation

// MARK: - File Operation Types

enum FileOperationType: String, Codable, CaseIterable {
    case create = "create"
    case modify = "modify" 
    case delete = "delete"
    case move = "move"
    case copy = "copy"
    case rename = "rename"
    
    var displayName: String {
        switch self {
        case .create: return "Created"
        case .modify: return "Modified"
        case .delete: return "Deleted"
        case .move: return "Moved"
        case .copy: return "Copied"
        case .rename: return "Renamed"
        }
    }
    
    var emoji: String {
        switch self {
        case .create: return "📄"
        case .modify: return "✏️"
        case .delete: return "🗑️"
        case .move: return "📁"
        case .copy: return "📋"
        case .rename: return "🔄"
        }
    }
}