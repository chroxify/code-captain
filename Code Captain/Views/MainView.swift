import SwiftUI

struct MainView: View {
    @StateObject private var store = CodeCaptainStore()
    @State private var showingAddProject = false
    @State private var showingAddSession = false
    @State private var showingSettings = false
    @State private var isInspectorPresented = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            DetailView(store: store, isInspectorPresented: $isInspectorPresented)
        }
        .inspector(isPresented: $isInspectorPresented) {
            // Inspector content - only show if we have a selected session
            if let session = store.selectedSession {
                VStack(spacing: 0) {
                    // Toolbar spacer - creates visual separation
                    Color.clear
                        .frame(height: 0) // Standard macOS toolbar height
                    
                    // Separator below toolbar
                    Divider()
                    
                    // Main content area
                    VSplitView {
                        // Top section: TODOs (50%)
                        TodoSectionView(session: session)
                            .frame(minHeight: 150)
                        
                        // Bottom section: Terminal (50%)
                        SwiftTerminalSectionView(session: session, store: store)
                            .frame(minHeight: 150)
                    }
                }
                .inspectorColumnWidth(min: 250, ideal: 300)
                .toolbar {
                    Button("", systemImage: "sidebar.right") {
                        isInspectorPresented.toggle()
                    }
                }
            } else {
                VStack(spacing: 0) {
                    // Toolbar spacer - creates visual separation
                    Color.clear
                        .frame(height: 0) // Standard macOS toolbar height
                    
                    // Separator below toolbar
                    Divider()
                    
                    // Main content area
                    VStack {
                        Text("No Session Selected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Select a session to view tools and terminal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .inspectorColumnWidth(min: 250, ideal: 300, max: 450)
                .toolbar {
                    Button("", systemImage: "sidebar.right") {
                        isInspectorPresented.toggle()
                    }
                }
            }
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
            ToolbarItemGroup(placement: .primaryAction) {
                Button("New Session") {
                    showingAddSession = true
                }
                .disabled(store.selectedProject == nil)
                
                Button("New Project") {
                    showingAddProject = true
                }
            }
            
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
                .help("Settings")
            }
        }
    }
}

struct SidebarView: View {
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        List(selection: $store.selectedSession) {
            Section("Projects") {
                ForEach(store.projects) { project in
                    ProjectRowView(project: project, store: store)
                }
            }
        }
        .navigationTitle("Code Captain")
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
                    .tag(session)
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
                
                // Active session indicator
                if project.hasActiveSessions {
                    Circle()
                        .fill(Color.green)
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

struct SessionRowView: View {
    let session: Session
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        HStack {
            Image(systemName: session.state.systemImageName)
                .foregroundColor(colorForState(session.state))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(.subheadline)
                
                Text(session.state.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if session.isActive {
                Button(action: {
                    Task {
                        await store.stopSession(session)
                    }
                }) {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            } else if session.canStart {
                Button(action: {
                    Task {
                        await store.startSession(session)
                    }
                }) {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onTapGesture {
            store.selectSession(session)
        }
        .contextMenu {
            if session.canStart {
                Button("Start Session") {
                    Task {
                        await store.startSession(session)
                    }
                }
            }
            
            if session.canStop {
                Button("Stop Session") {
                    Task {
                        await store.stopSession(session)
                    }
                }
            }
            
            if session.state == .active {
                Button("Pause Session") {
                    Task {
                        await store.pauseSession(session)
                    }
                }
            }
            
            if session.state == .paused {
                Button("Resume Session") {
                    Task {
                        await store.resumeSession(session)
                    }
                }
            }
            
            Divider()
            
            Button("Delete Session", role: .destructive) {
                Task {
                    await store.deleteSession(session)
                }
            }
        }
    }
    
    private func colorForState(_ state: SessionState) -> Color {
        switch state {
        case .idle: return .secondary
        case .starting: return .orange
        case .active: return .green
        case .paused: return .yellow
        case .stopping: return .orange
        case .error: return .red
        }
    }
}

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
                    Text("Active Sessions")
                        .font(.subheadline)
                    Spacer()
                    Text("\(store.getActiveSessionsForProject(project).count)")
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

#Preview {
    MainView()
}
