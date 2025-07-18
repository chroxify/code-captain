import Foundation
import os.log

// MARK: - Log Levels

enum LogLevel: String, CaseIterable, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var emoji: String {
        switch self {
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

// MARK: - Log Categories

enum LogCategory: String, CaseIterable, Codable {
    case app = "APP"
    case ui = "UI"
    case provider = "PROVIDER"
    case git = "GIT"
    case project = "PROJECT"
    case session = "SESSION"
    case communication = "COMMUNICATION"
    case process = "PROCESS"
    case storage = "STORAGE"
    
    var osLog: OSLog {
        return OSLog(subsystem: Bundle.main.bundleIdentifier ?? "CodeCaptain", category: self.rawValue)
    }
}

// MARK: - Logger

class Logger {
    static let shared = Logger()
    
    private let dateFormatter: DateFormatter
    private let logFileManager: LogFileManager
    private let queue = DispatchQueue(label: "com.codecaptain.logger", qos: .utility)
    
    // Configuration
    var isLoggingEnabled = true
    var logToConsole = true
    var logToDisk = true
    var minimumLogLevel: LogLevel = .debug
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        logFileManager = LogFileManager()
    }
    
    // MARK: - Main Logging Methods
    
    func debug(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    
    private func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        guard isLoggingEnabled else { return }
        
        // Check minimum log level
        guard shouldLog(level: level) else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let context = "\(fileName):\(line) \(function)"
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = self.dateFormatter.string(from: Date())
            let logEntry = LogEntry(
                timestamp: timestamp,
                level: level,
                category: category,
                message: message,
                context: context
            )
            
            // Log to console
            if self.logToConsole {
                self.logToConsole(logEntry)
            }
            
            // Log to system log
            self.logToSystem(logEntry)
            
            // Log to disk
            if self.logToDisk {
                self.logFileManager.writeLog(logEntry)
            }
        }
    }
    
    private func shouldLog(level: LogLevel) -> Bool {
        let levels: [LogLevel] = [.debug, .info, .warning, .error]
        guard let currentIndex = levels.firstIndex(of: level),
              let minimumIndex = levels.firstIndex(of: minimumLogLevel) else {
            return true
        }
        return currentIndex >= minimumIndex
    }
    
    private func logToConsole(_ entry: LogEntry) {
        let formattedMessage = formatForConsole(entry)
        print(formattedMessage)
    }
    
    private func logToSystem(_ entry: LogEntry) {
        os_log("%{public}@", log: entry.category.osLog, type: entry.level.osLogType, entry.message)
    }
    
    private func formatForConsole(_ entry: LogEntry) -> String {
        return "[\(entry.timestamp)] \(entry.level.emoji) [\(entry.category.rawValue)] \(entry.message) | \(entry.context)"
    }
    
    // MARK: - Log Management
    
    func getAllLogs() -> [LogEntry] {
        return logFileManager.readAllLogs()
    }
    
    func getLogsForCategory(_ category: LogCategory) -> [LogEntry] {
        return logFileManager.readAllLogs().filter { $0.category == category }
    }
    
    func getLogsForLevel(_ level: LogLevel) -> [LogEntry] {
        return logFileManager.readAllLogs().filter { $0.level == level }
    }
    
    func clearLogs() {
        logFileManager.clearLogs()
    }
    
    func exportLogs() -> String {
        let logs = getAllLogs()
        return logs.map { formatForExport($0) }.joined(separator: "\n")
    }
    
    private func formatForExport(_ entry: LogEntry) -> String {
        return "[\(entry.timestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message) | \(entry.context)"
    }
    
    // MARK: - Configuration
    
    func setMinimumLogLevel(_ level: LogLevel) {
        minimumLogLevel = level
    }
    
    func enableCategory(_ category: LogCategory) {
        // Implementation for category filtering if needed
    }
    
    func disableCategory(_ category: LogCategory) {
        // Implementation for category filtering if needed
    }
}

// MARK: - Log Entry

struct LogEntry: Codable {
    let timestamp: String
    let level: LogLevel
    let category: LogCategory
    let message: String
    let context: String
}

// MARK: - Log File Manager

class LogFileManager {
    private let documentsDirectory: URL
    private let logFileName = "codecaptain.log"
    private let maxLogFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles = 5
    
    init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var logFileURL: URL {
        return documentsDirectory.appendingPathComponent(logFileName)
    }
    
    func writeLog(_ entry: LogEntry) {
        let logLine = formatLogEntry(entry)
        
        // Check if log rotation is needed
        if shouldRotateLog() {
            rotateLogFiles()
        }
        
        // Append to current log file
        appendToLogFile(logLine)
    }
    
    private func formatLogEntry(_ entry: LogEntry) -> String {
        return "[\(entry.timestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message) | \(entry.context)\n"
    }
    
    private func appendToLogFile(_ logLine: String) {
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                defer { fileHandle.closeFile() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(logLine.data(using: .utf8) ?? Data())
            } else {
                try logLine.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to write log to file: \(error)")
        }
    }
    
    private func shouldRotateLog() -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
            let fileSize = attributes[.size] as? Int ?? 0
            return fileSize > maxLogFileSize
        } catch {
            return false
        }
    }
    
    private func rotateLogFiles() {
        do {
            // Move current log to .1
            let rotatedURL = documentsDirectory.appendingPathComponent("\(logFileName).1")
            
            // Remove oldest log files
            for i in stride(from: maxLogFiles, to: 1, by: -1) {
                let oldURL = documentsDirectory.appendingPathComponent("\(logFileName).\(i)")
                let newURL = documentsDirectory.appendingPathComponent("\(logFileName).\(i + 1)")
                
                if FileManager.default.fileExists(atPath: oldURL.path) {
                    if i == maxLogFiles {
                        try FileManager.default.removeItem(at: oldURL)
                    } else {
                        try FileManager.default.moveItem(at: oldURL, to: newURL)
                    }
                }
            }
            
            // Move current log to .1
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                try FileManager.default.moveItem(at: logFileURL, to: rotatedURL)
            }
        } catch {
            print("Failed to rotate log files: \(error)")
        }
    }
    
    func readAllLogs() -> [LogEntry] {
        var allLogs: [LogEntry] = []
        
        // Read all log files
        for i in 0...maxLogFiles {
            let fileURL = i == 0 ? logFileURL : documentsDirectory.appendingPathComponent("\(logFileName).\(i)")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let lines = content.components(separatedBy: .newlines)
                    
                    for line in lines {
                        if let entry = parseLogEntry(line) {
                            allLogs.append(entry)
                        }
                    }
                } catch {
                    print("Failed to read log file: \(error)")
                }
            }
        }
        
        return allLogs.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func parseLogEntry(_ line: String) -> LogEntry? {
        // Parse log entry from formatted line
        // This is a simplified parser - you might want to make it more robust
        let pattern = #"\[(.*?)\] \[(.*?)\] \[(.*?)\] (.*?) \| (.*)"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
            
            if let match = matches.first, match.numberOfRanges == 6 {
                let timestamp = String(line[Range(match.range(at: 1), in: line)!])
                let levelString = String(line[Range(match.range(at: 2), in: line)!])
                let categoryString = String(line[Range(match.range(at: 3), in: line)!])
                let message = String(line[Range(match.range(at: 4), in: line)!])
                let context = String(line[Range(match.range(at: 5), in: line)!])
                
                guard let level = LogLevel(rawValue: levelString),
                      let category = LogCategory(rawValue: categoryString) else {
                    return nil
                }
                
                return LogEntry(
                    timestamp: timestamp,
                    level: level,
                    category: category,
                    message: message,
                    context: context
                )
            }
        } catch {
            print("Failed to parse log entry: \(error)")
        }
        
        return nil
    }
    
    func clearLogs() {
        do {
            // Remove all log files
            for i in 0...maxLogFiles {
                let fileURL = i == 0 ? logFileURL : documentsDirectory.appendingPathComponent("\(logFileName).\(i)")
                
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Failed to clear logs: \(error)")
        }
    }
    
    func getLogFileURLs() -> [URL] {
        var urls: [URL] = []
        
        for i in 0...maxLogFiles {
            let fileURL = i == 0 ? logFileURL : documentsDirectory.appendingPathComponent("\(logFileName).\(i)")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                urls.append(fileURL)
            }
        }
        
        return urls
    }
}

// MARK: - Convenience Extensions

extension Logger {
    func logFunctionEntry(_ function: String = #function, category: LogCategory = .app, file: String = #file, line: Int = #line) {
        debug("→ Entering \(function)", category: category, file: file, function: function, line: line)
    }
    
    func logFunctionExit(_ function: String = #function, category: LogCategory = .app, file: String = #file, line: Int = #line) {
        debug("← Exiting \(function)", category: category, file: file, function: function, line: line)
    }
    
    func logError(_ error: Error, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        self.error("Error: \(error.localizedDescription)", category: category, file: file, function: function, line: line)
    }
    
    func logResult<T>(_ result: Result<T, Error>, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        switch result {
        case .success(let value):
            debug("Success: \(value)", category: category, file: file, function: function, line: line)
        case .failure(let error):
            logError(error, category: category, file: file, function: function, line: line)
        }
    }
}