import SwiftUI
import SwiftTerm
import AppKit

struct SwiftTerminalView: NSViewRepresentable {
    let workingDirectory: URL
    @ObservedObject var terminalService: SwiftTerminalService
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = terminalService.createTerminalView(for: workingDirectory)
        
        // Configure terminal appearance and behavior
        terminalView.configureNativeColors()
        terminalView.allowMouseReporting = true
        
        // Enable key event handling - result can be ignored
        _ = terminalView.becomeFirstResponder()
        
        return terminalView
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Ensure the terminal can accept key events
        DispatchQueue.main.async {
            // Make sure the terminal is the first responder for keyboard input
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

/// SwiftUI wrapper for the terminal section
struct SwiftTerminalSectionView: View {
    let session: Session?
    @ObservedObject var store: CodeCaptainStore
    @StateObject private var terminalService = SwiftTerminalService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Terminal")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                if let session = session {
                    Text("Session: \(session.claudeSessionId?.prefix(8) ?? "None")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Status indicator
                Circle()
                    .fill(terminalService.isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlColor))
            
            Divider()
            
            // Terminal content
            Group {
                if let session = session,
                   let project = store.projects.first(where: { $0.id == session.projectId }) {
                    SwiftTerminalView(
                        workingDirectory: project.gitWorktreePath,
                        terminalService: terminalService
                    )
                    .background(Color.black)
                    .onTapGesture {
                        // Focus the terminal when clicked
                        DispatchQueue.main.async {
                            // This will trigger the updateNSView to make the terminal first responder
                        }
                    }
                } else {
                    VStack {
                        Text("No project selected")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Text("Select a project to start terminal")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                }
            }
        }
        .onDisappear {
            terminalService.stopTerminal()
        }
    }
}

// MARK: - Terminal Focus Helper

// Note: SwiftTerm's LocalProcessTerminalView already handles focus management internally
// We don't need to override methods since they're not open for overriding