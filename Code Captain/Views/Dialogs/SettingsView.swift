import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: CodeCaptainStore
    @Environment(\.dismiss) private var dismiss
    
    private let logger = Logger.shared
    
    @State private var logLevel: LogLevel = .debug
    @State private var showingLogExport = false
    @State private var exportedLogs = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Text("Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Placeholder for symmetry
                Button("") {}
                    .disabled(true)
                    .opacity(0)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            Form {
                Section(header: Text("Logging")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Log Level:")
                                .frame(minWidth: 100, alignment: .leading)
                            
                            Picker("Log Level", selection: $logLevel) {
                                ForEach(LogLevel.allCases, id: \.self) { level in
                                    Text("\(level.emoji) \(level.rawValue)")
                                        .tag(level)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: logLevel) { _, newValue in
                                logger.setMinimumLogLevel(newValue)
                                logger.info("Log level changed to: \(newValue.rawValue)", category: .app)
                            }
                            
                            Spacer()
                        }
                        
                        HStack {
                            Text("Actions:")
                                .frame(minWidth: 100, alignment: .leading)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Button("Export Logs") {
                                        exportLogs()
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button("Clear Logs") {
                                        clearLogs()
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Spacer()
                                }
                                
                                HStack {
                                    Button("View Log Files") {
                                        openLogDirectory()
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Log Statistics")) {
                    VStack(alignment: .leading, spacing: 8) {
                        let allLogs = logger.getAllLogs()
                        let logStats = getLogStatistics(allLogs)
                        
                        ForEach(LogLevel.allCases, id: \.self) { level in
                            HStack {
                                Text("\(level.emoji) \(level.rawValue):")
                                    .frame(minWidth: 100, alignment: .leading)
                                
                                Text("\(logStats[level] ?? 0) entries")
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total Logs:")
                                .frame(minWidth: 100, alignment: .leading)
                                .fontWeight(.medium)
                            
                            Text("\(allLogs.count) entries")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                }
                
                Section(header: Text("Log Categories")) {
                    VStack(alignment: .leading, spacing: 8) {
                        let allLogs = logger.getAllLogs()
                        let categoryStats = getCategoryStatistics(allLogs)
                        
                        ForEach(LogCategory.allCases, id: \.self) { category in
                            HStack {
                                Text("\(category.rawValue):")
                                    .frame(minWidth: 120, alignment: .leading)
                                
                                Text("\(categoryStats[category] ?? 0) entries")
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .sheet(isPresented: $showingLogExport) {
            LogExportView(logs: exportedLogs)
        }
        .onAppear {
            logLevel = logger.minimumLogLevel
        }
    }
    
    private func exportLogs() {
        logger.info("User requested log export", category: .app)
        exportedLogs = logger.exportLogs()
        showingLogExport = true
    }
    
    private func clearLogs() {
        logger.info("User requested log clear", category: .app)
        logger.clearLogs()
        logger.info("Logs cleared by user", category: .app)
    }
    
    private func openLogDirectory() {
        logger.info("User requested to open log directory", category: .app)
        let logFileManager = LogFileManager()
        let logFiles = logFileManager.getLogFileURLs()
        
        if let firstLogFile = logFiles.first {
            let logDirectory = firstLogFile.deletingLastPathComponent()
            NSWorkspace.shared.open(logDirectory)
        }
    }
    
    private func getLogStatistics(_ logs: [LogEntry]) -> [LogLevel: Int] {
        var stats: [LogLevel: Int] = [:]
        
        for level in LogLevel.allCases {
            stats[level] = logs.filter { $0.level == level }.count
        }
        
        return stats
    }
    
    private func getCategoryStatistics(_ logs: [LogEntry]) -> [LogCategory: Int] {
        var stats: [LogCategory: Int] = [:]
        
        for category in LogCategory.allCases {
            stats[category] = logs.filter { $0.category == category }.count
        }
        
        return stats
    }
}

struct LogExportView: View {
    let logs: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Done") {
                    dismiss()
                }
                
                Spacer()
                
                Text("Exported Logs")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logs, forType: .string)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                Text(logs)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    SettingsView(store: CodeCaptainStore())
}