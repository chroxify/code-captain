import Foundation
import SwiftTerm
import Combine
import AppKit

@MainActor
class SwiftTerminalService: ObservableObject {
    private let logger = Logger.shared
    
    @Published var isRunning = false
    
    private var terminalView: LocalProcessTerminalView?
    
    // MARK: - Terminal Management
    
    /// Create and configure a new SwiftTerm terminal view
    func createTerminalView(for workingDirectory: URL) -> LocalProcessTerminalView {
        logger.info("Creating SwiftTerm terminal view for: \(workingDirectory.path)", category: .provider)
        
        // Create LocalProcessTerminalView with a default frame - this handles everything for us
        let terminal = LocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        
        // Configure terminal appearance
        terminal.configureNativeColors()
        terminal.allowMouseReporting = true
        
        // Start the shell process in the working directory
        terminal.startProcess(
            executable: getShellExecutable(),
            args: getShellArgs(),
            environment: createEnvironmentArray()
        )
        
        // Store reference
        self.terminalView = terminal
        
        // Update UI state
        isRunning = true
        
        logger.info("SwiftTerm terminal view created successfully", category: .provider)
        
        return terminal
    }
    
    /// Stop the terminal session
    func stopTerminal() {
        logger.info("Stopping SwiftTerm terminal session", category: .provider)
        
        // SwiftTerm LocalProcessTerminalView doesn't have a direct terminate method
        // The process will be terminated when the view is deallocated
        terminalView = nil
        isRunning = false
    }
    
    // MARK: - Helper Methods
    
    private func getShellExecutable() -> String {
        // Get the user's preferred shell
        if let shell = Foundation.ProcessInfo.processInfo.environment["SHELL"] {
            return shell
        }
        
        // Fallback to common shells
        let commonShells = ["/bin/zsh", "/bin/bash", "/bin/sh"]
        for shell in commonShells {
            if FileManager.default.isExecutableFile(atPath: shell) {
                return shell
            }
        }
        
        return "/bin/sh" // Ultimate fallback
    }
    
    private func getShellArgs() -> [String] {
        // Use login shell to get proper environment
        return ["-l"]
    }
    
    private func createEnvironmentArray() -> [String] {
        var environment = Foundation.ProcessInfo.processInfo.environment
        
        // Terminal configuration
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        
        // Enable colors
        environment["FORCE_COLOR"] = "1"
        environment["CLICOLOR"] = "1"
        environment["CLICOLOR_FORCE"] = "1"
        
        // Set a clean prompt
        environment["PS1"] = "\\u@\\h:\\w$ "
        
        // Convert dictionary to array format for SwiftTerm
        return environment.map { "\($0.key)=\($0.value)" }
    }
}