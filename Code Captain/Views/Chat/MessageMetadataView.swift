import SwiftUI

struct MessageMetadataView: View {
    let metadata: MessageMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let filesChanged = metadata.filesChanged, !filesChanged.isEmpty {
                Label(
                    "Files: \(filesChanged.joined(separator: ", "))",
                    systemImage: "doc.text"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if let gitOps = metadata.gitOperations, !gitOps.isEmpty {
                Label(
                    "Git: \(gitOps.joined(separator: ", "))",
                    systemImage: "arrow.triangle.branch"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if let tools = metadata.toolsUsed, !tools.isEmpty {
                Label(
                    "Tools: \(tools.joined(separator: ", "))",
                    systemImage: "wrench"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}