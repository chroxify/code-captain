# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Code Captain** is a comprehensive macOS SwiftUI application that serves as a native desktop wrapper for Claude Code and other AI coding assistants. It provides a ChatGPT-inspired interface for managing multiple AI coding sessions across different projects, with advanced git integration, session isolation, and a native macOS inspector UI.

### Key Features

- **Multi-Project Management**: Add and manage multiple coding projects with automatic git worktree setup
- **Session Isolation**: Each session runs in its own git branch within a dedicated workspace
- **Multi-Provider Support**: Extensible architecture supporting Claude Code, OpenCode, and future providers
- **Native macOS Inspector**: SwiftUI inspector with resizable panels for TODOs and terminal
- **Integrated Terminal**: SwiftTerm-based terminal emulation with proper keyboard input support
- **Real-time Communication**: Live bidirectional communication with CLI-based AI assistants
- **Native macOS UI**: 100% SwiftUI interface with proper macOS design patterns
- **ChatGPT-Inspired Chat**: Modern message bubbles with metadata display and real-time updates

## Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -scheme "Code Captain" -configuration Debug build

# Build for release
xcodebuild -scheme "Code Captain" -configuration Release build

# Open in Xcode
open "Code Captain.xcodeproj"

# Run the built app
open "/Users/christo/Library/Developer/Xcode/DerivedData/Code_Captain-*/Build/Products/Debug/Code Captain.app"
```

### Testing
```bash
# Run unit tests
xcodebuild -scheme "Code Captain" -destination "platform=macOS" test -only-testing:CodeCaptainTests

# Run UI tests
xcodebuild -scheme "Code Captain" -destination "platform=macOS" test -only-testing:CodeCaptainUITests

# Run all tests
xcodebuild -scheme "Code Captain" -destination "platform=macOS" test
```

### Project Information
```bash
# List all schemes and targets
xcodebuild -list

# Show build settings
xcodebuild -showBuildSettings -scheme "Code Captain"
```

## Project Structure

### Main Application (`Code Captain/`)
```
Code Captain/
├── CodeCaptainApp.swift          # App entry point with WindowGroup
├── Models/                       # Core data models
│   ├── Project.swift            # Project model with git worktree management
│   ├── Session.swift            # Session model with state management
│   ├── Message.swift            # Message model with metadata
│   └── Provider.swift           # Provider protocol and types
├── Services/                     # Business logic layer
│   ├── ProjectService.swift     # Project CRUD and git operations
│   ├── SessionService.swift     # Session lifecycle management
│   ├── ProviderService.swift    # Centralized provider management
│   ├── SwiftTerminalService.swift # SwiftTerm terminal service
│   └── CodeCaptainStore.swift   # Main observable store
├── Providers/                    # AI provider implementations
│   └── ClaudeCodeProvider.swift # Claude Code CLI integration
├── Views/                        # SwiftUI views
│   ├── MainView.swift           # Main split-view interface with session selection
│   ├── ChatView.swift           # ChatGPT-inspired chat with native inspector
│   ├── SwiftTerminalView.swift  # SwiftTerm terminal integration
│   ├── AddProjectView.swift     # Project creation modal
│   ├── AddSessionView.swift     # Session creation modal
│   └── SettingsView.swift       # Application settings
├── Utils/                        # Utility extensions
│   ├── Extensions.swift         # Helper extensions
│   └── Logger.swift             # Logging utilities
└── Assets.xcassets/             # App icons and assets
```

### Test Targets
- **Code CaptainTests/**: Unit tests using Swift Testing framework
- **Code CaptainUITests/**: UI tests using XCTest framework

## Core Architecture

### Data Models
- **Project**: Represents a local git repository with automatic worktree setup
- **Session**: Individual AI assistant conversations with isolated git branches
- **Message**: Chat messages with rich metadata (files changed, git operations, tools used)
- **Provider**: Pluggable AI assistant implementations (Claude Code, OpenCode, etc.)

### Services Layer
- **ProjectService**: Manages project lifecycle, git worktree creation/cleanup
- **SessionService**: Handles session creation, state management, message routing
- **ProviderService**: Centralized management of all AI providers with generic interface
- **SwiftTerminalService**: Terminal emulation using SwiftTerm framework
- **CodeCaptainStore**: Main @MainActor observable store for UI state

### Git Integration
Each project automatically creates a `CodeCaptain/workspace` directory as a git worktree:
```
your-project/
├── .git/                    # Original repository
├── src/                     # Your project files
├── CodeCaptain/
│   └── workspace/           # Isolated worktree
│       ├── .git            # Worktree git metadata
│       └── [project files] # Working copies for AI sessions
```

Each session creates its own branch: `session-{uuid}-{name}`

### Provider Architecture
The app uses a generic provider system allowing easy integration of different AI assistants:

```swift
protocol CodeAssistantProvider {
    var name: String { get }
    var isAvailable: Bool { get }
    func createSession(in workingDirectory: URL) async throws -> String
    func sendMessage(_ message: String, workingDirectory: URL, sessionId: String?) async throws -> ProviderResponse
    func listSessions() async throws -> [ProviderSession]
}
```

Current providers:
- **ClaudeCodeProvider**: Integrates with Claude Code CLI using SDK commands (-p, --resume, --output-format json)
- **OpenCodeProvider**: Planned for OpenCode support
- **CustomProvider**: Extensible for future providers

### UI Architecture
- **Native SwiftUI**: 100% SwiftUI with proper macOS patterns
- **NavigationSplitView**: Sidebar for projects/sessions, main area for chat
- **Native Inspector**: SwiftUI inspector with resizable panels (250-450px width)
- **Session Selection**: Only current session appears highlighted in sidebar
- **Sheet Modals**: Native modal dialogs for project/session creation
- **Real-time Updates**: Combine and @Published for reactive UI updates
- **ChatGPT-Inspired**: Message bubbles, metadata display, smooth animations

## Key Technical Features

### Session Management
- **Lifecycle States**: idle, starting, active, paused, stopping, error
- **SDK Integration**: Uses Claude Code CLI with --print and --resume flags
- **Session Persistence**: Claude Code manages session state externally
- **Metadata Tracking**: File changes, git operations, tool usage

### Git Worktree System
- **Automatic Setup**: Creates `CodeCaptain/workspace` worktree on project add
- **Branch Isolation**: Each session gets unique branch
- **Cleanup**: Automatic worktree removal on project deletion
- **Conflict Prevention**: Isolated workspaces prevent interference

### Terminal Integration
- **SwiftTerm Framework**: Professional terminal emulation with proper keyboard input
- **LocalProcessTerminalView**: Native terminal view with shell integration
- **Focus Management**: Proper first responder handling for keyboard input
- **Environment Setup**: Configures TERM, colors, and shell environment
- **Inspector Integration**: Compact terminal view in resizable inspector panel

### Inspector UI
- **Native macOS Inspector**: Uses SwiftUI .inspector() modifier
- **Resizable Panels**: Drag-to-resize with native handle (250-450px width)
- **VSplitView Layout**: TODOs section (top) and Terminal section (bottom)
- **Collapsible Sections**: Expandable/collapsible content areas
- **Toolbar Integration**: Inspector toggle button in native toolbar location

### Communication System
- **Non-Interactive CLI**: Uses Claude Code with --print flag for one-shot commands
- **JSON Output**: Structured responses with --output-format json
- **Session Resumption**: --resume flag for continuing conversations
- **Error Handling**: Comprehensive error handling and recovery
- **Background Processing**: All CLI operations on background queues

### Performance Optimizations
- **Lazy Loading**: Messages and UI elements loaded on demand
- **Background Processing**: All CLI operations on background queues
- **Memory Management**: Proper cleanup of processes and streams
- **Efficient Updates**: Minimal UI updates through Combine

## Platform Requirements

- **macOS**: 14.0+ (macOS Sonoma)
- **Xcode**: 15.0+ with Swift 5.9+
- **Claude Code CLI**: Must be installed and accessible
- **Git**: Required for worktree functionality
- **SwiftTerm**: Integrated as Swift Package Manager dependency

## Configuration

### Claude Code Setup
The app expects Claude Code to be installed at one of these locations:
- `/Users/{username}/.bun/bin/claude` (Bun installation)
- `/opt/homebrew/bin/claude` (Homebrew)
- `/usr/local/bin/claude` (System)
- `/usr/bin/claude` (System)

The app automatically detects Node.js/Bun installations and handles JavaScript-based Claude Code installations.

### App Permissions
- **File Access**: App can read/write to selected project directories
- **Process Creation**: Can spawn CLI processes for AI providers
- **Network**: Required for Claude Code API access

## Troubleshooting

### Common Issues
1. **Provider Not Available**: Ensure Claude Code CLI is installed and in PATH
2. **Git Worktree Errors**: Verify project is a valid git repository
3. **Session Start Failures**: Check CLI process permissions and arguments
4. **Terminal Input Issues**: Ensure SwiftTerm terminal has proper focus
5. **Inspector Not Resizing**: Check that .inspectorColumnWidth() is properly set

### Debug Commands
```bash
# Check Claude Code installation
which claude

# Test Claude Code manually
claude --help

# Check git worktree support
git worktree --help

# Test Claude Code with SDK flags
claude -p "Hello" --output-format json
```

## Recent Major Updates

### SwiftTerm Integration
- **Complete Terminal Rewrite**: Replaced custom terminal with SwiftTerm framework
- **Keyboard Input Fix**: Proper first responder handling for terminal input
- **Focus Management**: Native focus handling with LocalProcessTerminalView
- **Simplified Implementation**: Reduced from 292 lines to 96 lines

### Native Inspector UI
- **Replaced Custom Sidebar**: Switched from HSplitView to native SwiftUI inspector
- **Resizable Panels**: Native drag-to-resize with proper constraints
- **Toolbar Integration**: Inspector toggle in native macOS toolbar location
- **Preserved Terminal**: Kept exact same SwiftTerminalSectionView for compatibility

### Generic Provider Architecture
- **Centralized Provider Management**: ProviderService handles all providers
- **Generic Interface**: CodeAssistantProvider protocol for extensibility
- **SDK Integration**: Claude Code CLI with --print and --resume flags
- **Structured Responses**: JSON output parsing with metadata extraction

### Session Selection Fix
- **Highlighted Sessions Only**: Only current session appears selected in sidebar
- **Visual Clarity**: Projects serve as section headers without selection highlighting
- **Improved UX**: Clear indication of active session vs project structure

## Future Enhancements

### Planned Features
- **OpenCode Integration**: Support for OpenCode provider
- **Session Templates**: Pre-configured session types
- **Export/Import**: Session and project backup/restore
- **Search**: Global search across all conversations
- **Notifications**: System notifications for session events
- **Plugin System**: Third-party provider support
- **Advanced Terminal**: Multiple terminal tabs and session management

### Technical Improvements
- **Performance**: Virtual scrolling for large conversations
- **Accessibility**: Full VoiceOver and accessibility support
- **Testing**: Comprehensive unit and UI test coverage
- **Documentation**: In-app help and documentation
- **Terminal Enhancements**: Split panes, custom themes, and advanced features