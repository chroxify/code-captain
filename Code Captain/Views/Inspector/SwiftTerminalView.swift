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
        VStack(alignment: .leading, spacing: 12) {
            // Header (similar to FileChangesOverviewView)
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text("Terminal")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let session = session {
                    Text(session.providerSessionId?.prefix(8) ?? "None")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                // Status indicator
                Circle()
                    .fill(terminalService.isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 2)
            
            // Terminal content
            Group {
                if let session = session,
                   let project = store.projects.first(where: { $0.id == session.projectId }) {
                    SwiftTerminalView(
                        workingDirectory: project.gitWorktreePath,
                        terminalService: terminalService
                    )
                    .onTapGesture {
                        // Focus the terminal when clicked
                        DispatchQueue.main.async {
                            // This will trigger the updateNSView to make the terminal first responder
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("No project selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Select a project to start terminal")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .onDisappear {
            terminalService.stopTerminal()
        }
        .padding(12)
    }
}
