import SwiftUI

struct DetailView: View {
    @ObservedObject var store: CodeCaptainStore
    @Binding var isInspectorPresented: Bool
    
    var body: some View {
        Group {
            if let session = store.selectedSession {
                ChatView(sessionId: session.id, store: store)
            } else if let project = store.selectedProject {
                ProjectDetailView(project: project, store: store)
            } else {
                EmptyStateView()
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Welcome to Code Captain")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Create a new project to get started with Claude Code sessions.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: project.providerType.systemImageName)
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text(project.displayName)
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text(project.path.path)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sessions")
                        .font(.headline)
                    Spacer()
                    Text("\(store.getSessionsForProject(project)?.count ?? 0) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Processing Sessions")
                        .font(.subheadline)
                    Spacer()
                    Text("\(store.getProcessingSessionsForProject(project).count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Button("New Session") {
                Task {
                    await store.createSession(for: project, name: "New Session")
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
    }
}