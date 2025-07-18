# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Code Captain** is a comprehensive macOS SwiftUI application that serves as a native desktop wrapper for Claude Code and other AI coding assistants. It provides a ChatGPT-inspired interface for managing multiple AI coding sessions across different projects, with advanced git integration and session isolation.

### Key Features

- **Multi-Project Management**: Add and manage multiple coding projects with automatic git worktree setup
- **Session Isolation**: Each session runs in its own git branch within a dedicated workspace
- **Multi-Provider Support**: Extensible architecture supporting Claude Code, OpenCode, and future providers
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
│   ├── CommunicationService.swift # Provider communication coordinator
│   ├── ProcessManager.swift     # CLI process management
│   └── CodeCaptainStore.swift   # Main observable store
├── Providers/                    # AI provider implementations
│   └── ClaudeCodeProvider.swift # Claude Code CLI integration
├── Views/                        # SwiftUI views
│   ├── MainView.swift           # Main split-view interface
│   ├── ChatView.swift           # ChatGPT-inspired chat interface
│   ├── AddProjectView.swift     # Project creation modal
│   ├── AddSessionView.swift     # Session creation modal
│   └── ContentView.swift        # Legacy view (kept for compatibility)
├── Utils/                        # Utility extensions
│   └── Extensions.swift         # Helper extensions
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
- **CommunicationService**: Coordinates between UI and AI providers
- **ProcessManager**: Low-level CLI process management with stream handling
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
    func startSession(config: SessionConfig) async throws -> SessionHandle
    func sendMessage(_ message: String, to session: SessionHandle) async throws
    func receiveMessages(from session: SessionHandle) -> AsyncStream<ProviderMessage>
    func endSession(_ session: SessionHandle) async throws
}
```

Current providers:
- **ClaudeCodeProvider**: Integrates with Claude Code CLI
- **OpenCodeProvider**: Planned for OpenCode support
- **CustomProvider**: Extensible for future providers

### UI Architecture
- **Native SwiftUI**: 100% SwiftUI with proper macOS patterns
- **NavigationSplitView**: Sidebar for projects/sessions, main area for chat
- **Sheet Modals**: Native modal dialogs for project/session creation
- **Real-time Updates**: Combine and @Published for reactive UI updates
- **ChatGPT-Inspired**: Message bubbles, metadata display, smooth animations

## Key Technical Features

### Session Management
- **Lifecycle States**: idle, starting, active, paused, stopping, error
- **Process Isolation**: Each session runs in separate CLI process
- **Real-time Streaming**: AsyncStream for live message updates
- **Metadata Tracking**: File changes, git operations, tool usage

### Git Worktree System
- **Automatic Setup**: Creates `CodeCaptain/workspace` worktree on project add
- **Branch Isolation**: Each session gets unique branch
- **Cleanup**: Automatic worktree removal on project deletion
- **Conflict Prevention**: Isolated workspaces prevent interference

### Communication System
- **Bidirectional**: Full duplex communication with CLI processes
- **Error Handling**: Comprehensive error handling and recovery
- **Stream Management**: Proper stdin/stdout/stderr handling
- **Message Parsing**: Intelligent parsing of CLI output

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

## Configuration

### Claude Code Setup
The app expects Claude Code to be installed at one of these locations:
- `/opt/homebrew/bin/claude`
- `/usr/local/bin/claude`
- `/usr/bin/claude`

### App Permissions
- **File Access**: App can read/write to selected project directories
- **Process Creation**: Can spawn CLI processes for AI providers
- **Network**: If providers require internet access

## Troubleshooting

### Common Issues
1. **Provider Not Available**: Ensure Claude Code CLI is installed and in PATH
2. **Git Worktree Errors**: Verify project is a valid git repository
3. **Session Start Failures**: Check CLI process permissions and arguments
4. **UI Layout Issues**: Ensure proper SwiftUI view hierarchy

### Debug Commands
```bash
# Check Claude Code installation
which claude

# Test Claude Code manually
claude --help

# Check git worktree support
git worktree --help
```

## Future Enhancements

### Planned Features
- **OpenCode Integration**: Support for OpenCode provider
- **Session Templates**: Pre-configured session types
- **Export/Import**: Session and project backup/restore
- **Search**: Global search across all conversations
- **Notifications**: System notifications for session events
- **Plugin System**: Third-party provider support

### Technical Improvements
- **Performance**: Virtual scrolling for large conversations
- **Accessibility**: Full VoiceOver and accessibility support
- **Testing**: Comprehensive unit and UI test coverage
- **Documentation**: In-app help and documentation