import SwiftUI

struct MainView: View {
    @StateObject private var store = CodeCaptainStore()
    @State private var showingAddProject = false
    @State private var showingAddSession = false
    @State private var showingSettings = false
    @State private var isInspectorPresented = false
    @State private var currentSidebarView: SidebarViewType = .projects
    
    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, currentView: $currentSidebarView)
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            DetailView(store: store, isInspectorPresented: $isInspectorPresented)
        }
        .inspector(isPresented: $isInspectorPresented) {
            InspectorView(session: store.selectedSession, store: store, isInspectorPresented: $isInspectorPresented)
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView(store: store)
        }
        .sheet(isPresented: $showingAddSession) {
            AddSessionView(store: store)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store)
        }
        .alert("Error", isPresented: .constant(store.error != nil)) {
            Button("OK") {
                store.error = nil
            }
        } message: {
            if let error = store.error {
                Text(error)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                // Session status indicator
                if let session = store.selectedSession {
                    HStack(spacing: 8) {
                        LiveActivityIndicator(state: session.state).scaleEffect(1.1)
                        
                        VStack(alignment: .leading) {
                            // Session name (top row)
                            Text(session.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            
                            // Project, status, and todos (bottom row)
                            HStack(spacing: 4) {
                                // Project name
                                if let project = store.projects.first(where: { $0.id == session.projectId }) {
                                    Text(project.displayName)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                // Status
                                Text(session.state.displayName)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(colorForState(session.state))
                                
                                // Todo count if todos exist
                                if !session.todos.isEmpty {
                                    Text("• \(session.completedTodosCount)/\(session.totalTodosCount)")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .animation(.none, value: session.state)
                    .animation(.none, value: session.todos.count)
                    .animation(.none, value: session.completedTodosCount)
                }
                
                Spacer()
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    showingAddSession = true
                }) {
                    Image(systemName: "plus")
                }
                .disabled(store.selectedProject == nil)
                .help("New Session")
                
                Button(action: {
                    showingAddProject = true
                }) {
                    Image(systemName: "folder.badge.plus")
                }
                .help("New Project")
            }
        }
    }
    
    private func colorForState(_ state: SessionState) -> Color {
        switch state {
        case .idle: return .secondary
        case .processing: return .orange
        case .waitingForInput: return .yellow
        case .readyForReview: return .green
        case .error: return .red
        case .queued: return .blue
        case .archived: return .brown
        case .failed: return .red
        }
    }
}

#Preview {
    MainView()
}
