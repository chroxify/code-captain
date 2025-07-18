import SwiftUI

struct ProjectsView: View {
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        List(selection: $store.selectedSessionId) {
            Section("Projects") {
                ForEach(store.projects) { project in
                    ProjectRowView(project: project, store: store)
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}

struct ProjectRowView: View {
    let project: Project
    @ObservedObject var store: CodeCaptainStore
    @State private var isExpanded = true
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(store.getSessionsForProject(project) ?? []) { session in
                SessionRowView(session: session, store: store)
                    .tag(session.id)
            }
        } label: {
            HStack {
                Image(systemName: project.providerType.systemImageName)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.displayName)
                        .font(.headline)
                    Text(project.path.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Processing session indicator
                if project.hasProcessingSessions {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .contextMenu {
            Button("New Session") {
                Task {
                    await store.createSession(for: project, name: "New Session")
                }
            }
            
            Divider()
            
            Button("Remove Project", role: .destructive) {
                Task {
                    await store.removeProject(project)
                }
            }
        }
    }
}