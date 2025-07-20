import SwiftUI

/// File changes overview panel showing comprehensive statistics and visual overview of file operations
struct FileChangesOverviewView: View {
    @ObservedObject var store: CodeCaptainStore
    let session: Session?
    
    private var summary: SessionFileChangesSummary? {
        guard let session = session else { return nil }
        return store.getFileChangesSummary(for: session)
    }
    
    private var hasChanges: Bool {
        summary?.hasChanges == true
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text("File Changes Overview")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if hasChanges {
                    Text("\(summary?.totalFilesAffected ?? 0) files")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 2)
            
            if hasChanges, let summary = summary {
                // Overview Statistics
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    // Modified Files
                    if !summary.modifiedFiles.isEmpty {
                        StatCardView(
                            icon: "pencil",
                            color: .blue,
                            count: summary.modifiedFiles.count,
                            label: "Modified",
                            files: summary.modifiedFiles
                        )
                    }
                    
                    // Created Files
                    if !summary.createdFiles.isEmpty {
                        StatCardView(
                            icon: "plus.circle",
                            color: .green,
                            count: summary.createdFiles.count,
                            label: "Created",
                            files: summary.createdFiles
                        )
                    }
                    
                    // Deleted Files
                    if !summary.deletedFiles.isEmpty {
                        StatCardView(
                            icon: "trash",
                            color: .red,
                            count: summary.deletedFiles.count,
                            label: "Deleted",
                            files: summary.deletedFiles
                        )
                    }
                    
                    // Renamed Files
                    if !summary.renamedFiles.isEmpty {
                        RenameCardView(
                            count: summary.renamedFiles.count,
                            renames: summary.renamedFiles
                        )
                    }
                }
                
                // Summary Text
                if summary.messageCount > 0 {
                    HStack {
                        Text(summary.displaySummary)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Text("across \(summary.messageCount) message\(summary.messageCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                
            } else {
                // No changes state
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    Text("No file changes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if session?.messages.isEmpty == true {
                        Text("Send a message to start tracking")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .padding(12)
    }
}

/// Individual statistic card for file operations
struct StatCardView: View {
    let icon: String
    let color: Color
    let count: Int
    let label: String
    let files: [String]
    
    @State private var showingPopover = false
    
    var body: some View {
        Button(action: {
            if !files.isEmpty {
                showingPopover = true
            }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.caption2)
                    
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(files.isEmpty)
        .popover(isPresented: $showingPopover) {
            FileListPopover(title: "\(label) Files", files: files, icon: icon, color: color)
        }
    }
}

/// Special card for rename operations
struct RenameCardView: View {
    let count: Int
    let renames: [(from: String, to: String)]
    
    @State private var showingPopover = false
    
    var body: some View {
        Button(action: {
            if !renames.isEmpty {
                showingPopover = true
            }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text("Renamed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(renames.isEmpty)
        .popover(isPresented: $showingPopover) {
            RenameListPopover(renames: renames)
        }
    }
}

/// Popover showing list of affected files
struct FileListPopover: View {
    let title: String
    let files: [String]
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(files.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider()
            
            // File List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(files.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                                .frame(width: 12)
                            
                            Text(files[index])
                                .font(.caption)
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 200)
            .padding(.bottom, 8)
        }
        .frame(width: 300)
        .background(Color(.controlBackgroundColor))
    }
}

/// Popover showing list of renamed files
struct RenameListPopover: View {
    let renames: [(from: String, to: String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text("Renamed Files")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(renames.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider()
            
            // Rename List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(renames.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.secondary)
                                    .font(.caption2)
                                    .frame(width: 12)
                                
                                Text(renames[index].from)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .strikethrough()
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 12)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.right")
                                    .foregroundColor(.orange)
                                    .font(.caption2)
                                    .frame(width: 12)
                                
                                Text(renames[index].to)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 12)
                        }
                        .padding(.vertical, 2)
                        
                        if index < renames.count - 1 {
                            Divider()
                                .padding(.horizontal, 12)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
            .padding(.bottom, 8)
        }
        .frame(width: 350)
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Preview
struct FileChangesOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            FileChangesOverviewView(store: CodeCaptainStore(), session: nil)
                .frame(width: 300)
        }
        .padding()
    }
}
