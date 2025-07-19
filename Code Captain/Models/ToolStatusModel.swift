import Foundation
import SwiftUI

// MARK: - Tool Status State
enum ToolStatusState: Codable {
    case processing
    case completed(duration: TimeInterval?)
    case error(message: String)
}

// MARK: - Tool Status Data Model
struct ToolStatus: Identifiable, Hashable, Codable {
    let id: String
    let toolType: ToolAction
    let state: ToolStatusState
    let preview: String?
    let fullContent: String?
    let startTime: Date
    let endTime: Date?
    
    init(id: String, toolType: ToolAction, state: ToolStatusState, preview: String? = nil, fullContent: String? = nil, startTime: Date = Date(), endTime: Date? = nil) {
        self.id = id
        self.toolType = toolType
        self.state = state
        self.preview = preview
        self.fullContent = fullContent
        self.startTime = startTime
        self.endTime = endTime
    }
    
    // Computed properties for display
    var duration: TimeInterval? {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        }
        return nil
    }
    
    var isProcessing: Bool {
        if case .processing = state {
            return true
        }
        return false
    }
    
    var isCompleted: Bool {
        if case .completed = state {
            return true
        }
        return false
    }
    
    var isError: Bool {
        if case .error = state {
            return true
        }
        return false
    }
}

// MARK: - Tool Status Message Generator
extension ToolStatus {
    
    /// Generates the processing state label (present tense with "...")
    var processingLabel: String {
        switch toolType {
        // Core CLI Tools
        case .bash:
            if let preview = preview, !preview.isEmpty {
                return "Running \(preview.prefix(30))..."
            }
            return "Executing command..."
        case .strReplaceEditor, .strReplaceBasedEditTool:
            if let preview = preview, !preview.isEmpty {
                return "Editing \(preview)..."
            }
            return "Modifying file..."
        case .webSearch:
            if let preview = preview, !preview.isEmpty {
                return "Searching for \(preview)..."
            }
            return "Searching web..."
            
        // Advanced Claude Code Tools
        case .task:
            return "Analyzing task..."
        case .glob:
            if let preview = preview, !preview.isEmpty {
                return "Finding files matching \(preview)..."
            }
            return "Searching files..."
        case .grep:
            if let preview = preview, !preview.isEmpty {
                return "Searching for \(preview)..."
            }
            return "Text searching..."
        case .ls:
            if let preview = preview, !preview.isEmpty {
                return "Listing \(preview)..."
            }
            return "Listing directory..."
        case .exitPlanMode:
            return "Finalizing plan..."
        case .read:
            if let preview = preview, !preview.isEmpty {
                return "Reading \(preview)..."
            }
            return "Reading file..."
        case .edit:
            if let preview = preview, !preview.isEmpty {
                return "Editing \(preview)..."
            }
            return "Modifying file..."
        case .multiEdit:
            if let preview = preview, !preview.isEmpty {
                return "Multi-editing \(preview)..."
            }
            return "Making multiple edits..."
        case .write:
            if let preview = preview, !preview.isEmpty {
                return "Writing \(preview)..."
            }
            return "Creating file..."
        case .notebookRead:
            if let preview = preview, !preview.isEmpty {
                return "Reading notebook \(preview)..."
            }
            return "Opening notebook..."
        case .notebookEdit:
            if let preview = preview, !preview.isEmpty {
                return "Editing notebook \(preview)..."
            }
            return "Modifying notebook..."
        case .webFetch:
            if let preview = preview, !preview.isEmpty {
                return "Fetching \(preview)..."
            }
            return "Downloading content..."
        case .todoWrite:
            if let preview = preview, !preview.isEmpty {
                return "Updating \(preview)..."
            }
            return "Updating todos..."
        case .webSearchAdvanced:
            if let preview = preview, !preview.isEmpty {
                return "Deep searching \(preview)..."
            }
            return "Advanced web search..."
            
        // File System Operations
        case .fileRead:
            if let preview = preview, !preview.isEmpty {
                return "Reading \(preview)..."
            }
            return "Reading file..."
        case .fileWrite:
            if let preview = preview, !preview.isEmpty {
                return "Writing \(preview)..."
            }
            return "Writing file..."
        case .fileCreate:
            if let preview = preview, !preview.isEmpty {
                return "Creating \(preview)..."
            }
            return "Creating file..."
        case .fileDelete:
            if let preview = preview, !preview.isEmpty {
                return "Deleting \(preview)..."
            }
            return "Deleting file..."
        case .fileMove:
            if let preview = preview, !preview.isEmpty {
                return "Moving \(preview)..."
            }
            return "Moving file..."
        case .fileCopy:
            if let preview = preview, !preview.isEmpty {
                return "Copying \(preview)..."
            }
            return "Copying file..."
        case .directoryList:
            if let preview = preview, !preview.isEmpty {
                return "Listing \(preview)..."
            }
            return "Exploring directory..."
        case .directoryCreate:
            if let preview = preview, !preview.isEmpty {
                return "Creating \(preview)..."
            }
            return "Creating directory..."
            
        // Git Operations
        case .gitStatus:
            return "Checking git status..."
        case .gitAdd:
            return "Staging changes..."
        case .gitCommit:
            if let preview = preview, !preview.isEmpty {
                return "Committing \(preview)..."
            }
            return "Creating commit..."
        case .gitPush:
            return "Pushing to remote..."
        case .gitPull:
            return "Pulling changes..."
        case .gitBranch:
            if let preview = preview, !preview.isEmpty {
                return "Working with branch \(preview)..."
            }
            return "Managing branches..."
        case .gitCheckout:
            if let preview = preview, !preview.isEmpty {
                return "Switching to \(preview)..."
            }
            return "Switching branch..."
        case .gitMerge:
            if let preview = preview, !preview.isEmpty {
                return "Merging \(preview)..."
            }
            return "Merging branches..."
        case .gitDiff:
            return "Comparing changes..."
        case .gitLog:
            return "Checking history..."
            
        // Code Analysis
        case .codeAnalysis:
            if let preview = preview, !preview.isEmpty {
                return "Analyzing \(preview)..."
            }
            return "Analyzing code..."
        case .syntaxCheck:
            if let preview = preview, !preview.isEmpty {
                return "Checking syntax in \(preview)..."
            }
            return "Validating syntax..."
        case .lintCheck:
            if let preview = preview, !preview.isEmpty {
                return "Linting \(preview)..."
            }
            return "Running linter..."
        case .formatCode:
            if let preview = preview, !preview.isEmpty {
                return "Formatting \(preview)..."
            }
            return "Formatting code..."
        case .findReferences:
            if let preview = preview, !preview.isEmpty {
                return "Finding references to \(preview)..."
            }
            return "Finding references..."
        case .findDefinition:
            if let preview = preview, !preview.isEmpty {
                return "Finding definition of \(preview)..."
            }
            return "Finding definition..."
            
        // Build & Test
        case .buildProject:
            return "Building project..."
        case .runTests:
            if let preview = preview, !preview.isEmpty {
                return "Running tests in \(preview)..."
            }
            return "Running tests..."
        case .runCommand:
            if let preview = preview, !preview.isEmpty {
                return "Running \(preview.prefix(30))..."
            }
            return "Executing command..."
        case .installDependencies:
            if let preview = preview, !preview.isEmpty {
                return "Installing via \(preview)..."
            }
            return "Installing packages..."
            
        // Database Operations
        case .dbQuery:
            if let preview = preview, !preview.isEmpty {
                return "Querying \(preview.prefix(40))..."
            }
            return "Running database query..."
        case .dbSchema:
            if let preview = preview, !preview.isEmpty {
                return "Checking schema for \(preview)..."
            }
            return "Inspecting schema..."
        case .dbMigration:
            if let preview = preview, !preview.isEmpty {
                return "Running migration \(preview)..."
            }
            return "Migrating database..."
            
        // API & Network
        case .apiRequest:
            if let preview = preview, !preview.isEmpty {
                return "Requesting \(preview)..."
            }
            return "Making API call..."
        case .curlRequest:
            if let preview = preview, !preview.isEmpty {
                return "Fetching \(preview)..."
            }
            return "Sending HTTP request..."
        case .pingHost:
            if let preview = preview, !preview.isEmpty {
                return "Pinging \(preview)..."
            }
            return "Testing connection..."
        case .dnsLookup:
            if let preview = preview, !preview.isEmpty {
                return "Looking up \(preview)..."
            }
            return "Resolving DNS..."
            
        // System Operations
        case .systemInfo:
            return "Getting system info..."
        case .processInfo:
            if let preview = preview, !preview.isEmpty {
                return "Checking process \(preview)..."
            }
            return "Inspecting processes..."
        case .memoryUsage:
            return "Checking memory usage..."
        case .diskUsage:
            if let preview = preview, !preview.isEmpty {
                return "Checking disk usage for \(preview)..."
            }
            return "Analyzing disk space..."
        }
    }
    
    /// Generates the completed state label (past tense, optionally with duration)
    var completedLabel: String {
        let durationText: String
        if let duration = duration {
            if duration < 1.0 {
                durationText = ""
            } else if duration < 60.0 {
                durationText = " (\(String(format: "%.1f", duration))s)"
            } else {
                let minutes = Int(duration / 60)
                let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
                durationText = " (\(minutes)m \(seconds)s)"
            }
        } else {
            durationText = ""
        }
        
        switch toolType {
        // Core CLI Tools
        case .bash:
            if let preview = preview, !preview.isEmpty {
                return "Executed \(preview.prefix(20))\(durationText)"
            }
            return "Command executed\(durationText)"
        case .strReplaceEditor, .strReplaceBasedEditTool:
            if let preview = preview, !preview.isEmpty {
                return "Modified \(preview)\(durationText)"
            }
            return "File modified\(durationText)"
        case .webSearch:
            if let preview = preview, !preview.isEmpty {
                return "Found results for \(preview)\(durationText)"
            }
            return "Web search completed\(durationText)"
            
        // Advanced Claude Code Tools
        case .task:
            return "Task analyzed\(durationText)"
        case .glob:
            if let preview = preview, !preview.isEmpty {
                return "Found files matching \(preview)\(durationText)"
            }
            return "File search completed\(durationText)"
        case .grep:
            if let preview = preview, !preview.isEmpty {
                return "Found \(preview) matches\(durationText)"
            }
            return "Text search completed\(durationText)"
        case .ls:
            if let preview = preview, !preview.isEmpty {
                return "Listed \(preview)\(durationText)"
            }
            return "Directory listed\(durationText)"
        case .exitPlanMode:
            return "Plan finalized\(durationText)"
        case .read:
            if let preview = preview, !preview.isEmpty {
                return "Read \(preview)\(durationText)"
            }
            return "File read\(durationText)"
        case .edit:
            if let preview = preview, !preview.isEmpty {
                return "Edited \(preview)\(durationText)"
            }
            return "File edited\(durationText)"
        case .multiEdit:
            if let preview = preview, !preview.isEmpty {
                return "Multi-edited \(preview)\(durationText)"
            }
            return "Multiple edits completed\(durationText)"
        case .write:
            if let preview = preview, !preview.isEmpty {
                return "Created \(preview)\(durationText)"
            }
            return "File created\(durationText)"
        case .notebookRead:
            if let preview = preview, !preview.isEmpty {
                return "Read notebook \(preview)\(durationText)"
            }
            return "Notebook opened\(durationText)"
        case .notebookEdit:
            if let preview = preview, !preview.isEmpty {
                return "Edited notebook \(preview)\(durationText)"
            }
            return "Notebook modified\(durationText)"
        case .webFetch:
            if let preview = preview, !preview.isEmpty {
                return "Downloaded \(preview)\(durationText)"
            }
            return "Content downloaded\(durationText)"
        case .todoWrite:
            if let preview = preview, !preview.isEmpty {
                return "Updated \(preview)\(durationText)"
            }
            return "Todos updated\(durationText)"
        case .webSearchAdvanced:
            if let preview = preview, !preview.isEmpty {
                return "Deep searched \(preview)\(durationText)"
            }
            return "Advanced search completed\(durationText)"
            
        // File System Operations
        case .fileRead:
            if let preview = preview, !preview.isEmpty {
                return "Read \(preview)\(durationText)"
            }
            return "File read\(durationText)"
        case .fileWrite:
            if let preview = preview, !preview.isEmpty {
                return "Wrote \(preview)\(durationText)"
            }
            return "File written\(durationText)"
        case .fileCreate:
            if let preview = preview, !preview.isEmpty {
                return "Created \(preview)\(durationText)"
            }
            return "File created\(durationText)"
        case .fileDelete:
            if let preview = preview, !preview.isEmpty {
                return "Deleted \(preview)\(durationText)"
            }
            return "File deleted\(durationText)"
        case .fileMove:
            if let preview = preview, !preview.isEmpty {
                return "Moved \(preview)\(durationText)"
            }
            return "File moved\(durationText)"
        case .fileCopy:
            if let preview = preview, !preview.isEmpty {
                return "Copied \(preview)\(durationText)"
            }
            return "File copied\(durationText)"
        case .directoryList:
            if let preview = preview, !preview.isEmpty {
                return "Listed \(preview)\(durationText)"
            }
            return "Directory explored\(durationText)"
        case .directoryCreate:
            if let preview = preview, !preview.isEmpty {
                return "Created \(preview)/\(durationText)"
            }
            return "Directory created\(durationText)"
            
        // Git Operations
        case .gitStatus:
            return "Git status checked\(durationText)"
        case .gitAdd:
            return "Changes staged\(durationText)"
        case .gitCommit:
            if let preview = preview, !preview.isEmpty {
                return "Committed \(preview)\(durationText)"
            }
            return "Commit created\(durationText)"
        case .gitPush:
            return "Pushed to remote\(durationText)"
        case .gitPull:
            return "Changes pulled\(durationText)"
        case .gitBranch:
            if let preview = preview, !preview.isEmpty {
                return "Branch \(preview) managed\(durationText)"
            }
            return "Branches managed\(durationText)"
        case .gitCheckout:
            if let preview = preview, !preview.isEmpty {
                return "Switched to \(preview)\(durationText)"
            }
            return "Branch switched\(durationText)"
        case .gitMerge:
            if let preview = preview, !preview.isEmpty {
                return "Merged \(preview)\(durationText)"
            }
            return "Branches merged\(durationText)"
        case .gitDiff:
            return "Changes compared\(durationText)"
        case .gitLog:
            return "History checked\(durationText)"
            
        // Code Analysis
        case .codeAnalysis:
            if let preview = preview, !preview.isEmpty {
                return "Analyzed \(preview)\(durationText)"
            }
            return "Code analyzed\(durationText)"
        case .syntaxCheck:
            if let preview = preview, !preview.isEmpty {
                return "Validated syntax in \(preview)\(durationText)"
            }
            return "Syntax validated\(durationText)"
        case .lintCheck:
            if let preview = preview, !preview.isEmpty {
                return "Linted \(preview)\(durationText)"
            }
            return "Linting completed\(durationText)"
        case .formatCode:
            if let preview = preview, !preview.isEmpty {
                return "Formatted \(preview)\(durationText)"
            }
            return "Code formatted\(durationText)"
        case .findReferences:
            if let preview = preview, !preview.isEmpty {
                return "Found references to \(preview)\(durationText)"
            }
            return "References found\(durationText)"
        case .findDefinition:
            if let preview = preview, !preview.isEmpty {
                return "Found definition of \(preview)\(durationText)"
            }
            return "Definition found\(durationText)"
            
        // Build & Test
        case .buildProject:
            return "Project built\(durationText)"
        case .runTests:
            if let preview = preview, !preview.isEmpty {
                return "Tests ran in \(preview)\(durationText)"
            }
            return "Tests completed\(durationText)"
        case .runCommand:
            if let preview = preview, !preview.isEmpty {
                return "Executed \(preview.prefix(20))\(durationText)"
            }
            return "Command executed\(durationText)"
        case .installDependencies:
            if let preview = preview, !preview.isEmpty {
                return "Installed via \(preview)\(durationText)"
            }
            return "Packages installed\(durationText)"
            
        // Database Operations
        case .dbQuery:
            if let preview = preview, !preview.isEmpty {
                return "Queried \(preview.prefix(30))\(durationText)"
            }
            return "Database query completed\(durationText)"
        case .dbSchema:
            if let preview = preview, !preview.isEmpty {
                return "Inspected schema for \(preview)\(durationText)"
            }
            return "Schema inspected\(durationText)"
        case .dbMigration:
            if let preview = preview, !preview.isEmpty {
                return "Migrated \(preview)\(durationText)"
            }
            return "Database migrated\(durationText)"
            
        // API & Network
        case .apiRequest:
            if let preview = preview, !preview.isEmpty {
                return "Requested \(preview)\(durationText)"
            }
            return "API call completed\(durationText)"
        case .curlRequest:
            if let preview = preview, !preview.isEmpty {
                return "Fetched \(preview)\(durationText)"
            }
            return "HTTP request sent\(durationText)"
        case .pingHost:
            if let preview = preview, !preview.isEmpty {
                return "Pinged \(preview)\(durationText)"
            }
            return "Connection tested\(durationText)"
        case .dnsLookup:
            if let preview = preview, !preview.isEmpty {
                return "Resolved \(preview)\(durationText)"
            }
            return "DNS resolved\(durationText)"
            
        // System Operations
        case .systemInfo:
            return "System info retrieved\(durationText)"
        case .processInfo:
            if let preview = preview, !preview.isEmpty {
                return "Inspected process \(preview)\(durationText)"
            }
            return "Processes inspected\(durationText)"
        case .memoryUsage:
            return "Memory usage checked\(durationText)"
        case .diskUsage:
            if let preview = preview, !preview.isEmpty {
                return "Analyzed disk usage for \(preview)\(durationText)"
            }
            return "Disk space analyzed\(durationText)"
        }
    }
    
    /// Generates error state label
    var errorLabel: String {
        switch toolType {
        case .bash:
            return "Command failed"
        case .read:
            return "Failed to read file"
        case .edit:
            return "Failed to edit file"
        case .write:
            return "Failed to write file"
        default:
            return "\(toolType.displayName) failed"
        }
    }
    
    /// Custom icons for inline tool status (more intuitive than default)
    var customIconName: String {
        switch toolType {
        // Core CLI Tools
        case .bash:
            return "terminal.fill"
        case .strReplaceEditor, .strReplaceBasedEditTool:
            return "pencil.circle.fill"
        case .webSearch:
            return "magnifyingglass.circle.fill"
            
        // Advanced Claude Code Tools
        case .task:
            return "brain.head.profile"
        case .glob:
            return "doc.text.magnifyingglass"
        case .grep:
            return "text.magnifyingglass"
        case .ls:
            return "folder.fill"
        case .exitPlanMode:
            return "checkmark.circle.fill"
        case .read:
            return "doc.text.fill"
        case .edit:
            return "pencil.and.outline"
        case .multiEdit:
            return "pencil.tip.crop.circle.badge.plus"
        case .write:
            return "square.and.pencil.circle.fill"
        case .notebookRead:
            return "book.fill"
        case .notebookEdit:
            return "book.closed.fill"
        case .webFetch:
            return "arrow.down.circle.fill"
        case .todoWrite:
            return "checklist"
        case .webSearchAdvanced:
            return "globe.americas.fill"
            
        // File System Operations
        case .fileRead:
            return "doc.text.fill"
        case .fileWrite:
            return "square.and.pencil.circle.fill"
        case .fileCreate:
            return "plus.circle.fill"
        case .fileDelete:
            return "trash.fill"
        case .fileMove:
            return "arrow.right.circle.fill"
        case .fileCopy:
            return "doc.on.doc.fill"
        case .directoryList:
            return "folder.fill"
        case .directoryCreate:
            return "folder.fill.badge.plus"
            
        // Git Operations
        case .gitStatus:
            return "info.circle.fill"
        case .gitAdd:
            return "plus.circle.fill"
        case .gitCommit:
            return "checkmark.circle.fill"
        case .gitPush:
            return "arrow.up.circle.fill"
        case .gitPull:
            return "arrow.down.circle.fill"
        case .gitBranch:
            return "arrow.triangle.branch"
        case .gitCheckout:
            return "arrow.triangle.swap"
        case .gitMerge:
            return "arrow.triangle.merge"
        case .gitDiff:
            return "doc.plaintext.fill"
        case .gitLog:
            return "clock.fill"
            
        // Code Analysis
        case .codeAnalysis:
            return "magnifyingglass.circle.fill"
        case .syntaxCheck:
            return "checkmark.seal.fill"
        case .lintCheck:
            return "checkmark.circle.trianglebadge.exclamationmark"
        case .formatCode:
            return "textformat.size"
        case .findReferences:
            return "link.circle.fill"
        case .findDefinition:
            return "target"
            
        // Build & Test
        case .buildProject:
            return "hammer.fill"
        case .runTests:
            return "play.circle.fill"
        case .runCommand:
            return "play.rectangle.fill"
        case .installDependencies:
            return "square.and.arrow.down.fill"
            
        // Database Operations
        case .dbQuery:
            return "cylinder.fill"
        case .dbSchema:
            return "cylinder.split.1x2.fill"
        case .dbMigration:
            return "arrow.up.arrow.down.circle.fill"
            
        // API & Network
        case .apiRequest:
            return "network"
        case .curlRequest:
            return "arrow.left.arrow.right.circle.fill"
        case .pingHost:
            return "wifi.circle.fill"
        case .dnsLookup:
            return "globe.circle.fill"
            
        // System Operations
        case .systemInfo:
            return "info.circle.fill"
        case .processInfo:
            return "cpu.fill"
        case .memoryUsage:
            return "memorychip.fill"
        case .diskUsage:
            return "internaldrive.fill"
        }
    }
}

// MARK: - Hashable Conformance for ToolStatusState
extension ToolStatusState: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .processing:
            hasher.combine("processing")
        case .completed(let duration):
            hasher.combine("completed")
            hasher.combine(duration)
        case .error(let message):
            hasher.combine("error")
            hasher.combine(message)
        }
    }
    
    static func == (lhs: ToolStatusState, rhs: ToolStatusState) -> Bool {
        switch (lhs, rhs) {
        case (.processing, .processing):
            return true
        case (.completed(let lhsDuration), .completed(let rhsDuration)):
            return lhsDuration == rhsDuration
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}