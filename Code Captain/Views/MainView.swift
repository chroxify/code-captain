import SwiftUI

enum SidebarViewType: String, CaseIterable {
    case projects = "Projects"
    case sessions = "Agents"
    case dashboard = "Dashboard"
    case recent = "Recent"
    
    var systemImageName: String {
        switch self {
        case .projects: return "folder"
        case .sessions: return "brain"
        case .dashboard: return "gauge"
        case .recent: return "clock"
        }
    }
    
    var filledSystemImageName: String {
        switch self {
        case .projects: return "folder.fill"
        case .sessions: return "brain.fill"
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .recent: return "clock.fill"
        }
    }
}

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
                    ToolbarItem(placement: .primaryAction) {
                        Button("", systemImage: "sidebar.right") {
                            isInspectorPresented.toggle()
                        }
                        .help("Toggle Inspector")
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
                    ToolbarItem(placement: .primaryAction) {
                        Button("", systemImage: "sidebar.right") {
                            isInspectorPresented.toggle()
                        }
                        .help("Toggle Inspector")
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
            ToolbarItemGroup(placement: .navigation) {
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
                .help("Settings")
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
}

struct SidebarView: View {
    @ObservedObject var store: CodeCaptainStore
    @Binding var currentView: SidebarViewType
    
    var body: some View {
        VStack(spacing: 0) {
            // View toggle header
            SidebarViewToggle(currentView: $currentView)
            
            Divider()
            
            // Content based on current view
            Group {
                switch currentView {
                case .projects:
                    ProjectsView(store: store)
                case .sessions:
                    SessionsView(store: store)
                case .dashboard:
                    DashboardView(store: store)
                case .recent:
                    RecentView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Code Captain")
    }
}

struct SidebarViewToggle: View {
    @Binding var currentView: SidebarViewType
    
    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
            
            HStack(spacing: 12) {
                ForEach(SidebarViewType.allCases, id: \.self) { view in
                    Button(action: {
                        currentView = view
                    }) {
                        Image(systemName: currentView == view ? view.filledSystemImageName : view.systemImageName)
                            .font(.system(size: view == .sessions ? 12 : 13, weight: .medium))
                            .foregroundColor(currentView == view ? .accentColor : .secondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(view.rawValue)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Rectangle())
        }
    }
}

struct ProjectsView: View {
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        List(selection: $store.selectedSession) {
            Section("Projects") {
                ForEach(store.projects) { project in
                    ProjectRowView(project: project, store: store)
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}

struct SessionsView: View {
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        List(selection: $store.selectedSession) {
            let processingSessions = store.sessions.filter { $0.state == .processing }
            let waitingForInputSessions = store.sessions.filter { $0.state == .waitingForInput }
            let readyForReviewSessions = store.sessions.filter { $0.state == .readyForReview }
            let queuedSessions = store.sessions.filter { $0.state == .queued }
            let idleSessions = store.sessions.filter { $0.state == .idle }
            let failedSessions = store.sessions.filter { $0.state == .failed || $0.state == .error }
            let archivedSessions = store.sessions.filter { $0.state == .archived }
            
            if !processingSessions.isEmpty {
                Section("Processing (\(processingSessions.count))") {
                    ForEach(processingSessions.sorted { $0.priority.rawValue > $1.priority.rawValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session)
                    }
                }
            }
            
            if !waitingForInputSessions.isEmpty {
                Section("Waiting for Input (\(waitingForInputSessions.count))") {
                    ForEach(waitingForInputSessions.sorted { $0.priority.rawValue > $1.priority.rawValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session)
                    }
                }
            }
            
            if !readyForReviewSessions.isEmpty {
                Section("Ready for Review (\(readyForReviewSessions.count))") {
                    ForEach(readyForReviewSessions.sorted { $0.priority.rawValue > $1.priority.rawValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session)
                    }
                }
            }
            
            if !queuedSessions.isEmpty {
                Section("Queued (\(queuedSessions.count))") {
                    ForEach(queuedSessions.sorted { $0.priority.rawValue > $1.priority.rawValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session)
                    }
                }
            }
            
            if !idleSessions.isEmpty {
                Section("Idle (\(idleSessions.count))") {
                    ForEach(idleSessions.sorted { $0.lastActiveAt > $1.lastActiveAt }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session)
                    }
                }
            }
            
            if !failedSessions.isEmpty {
                Section("Failed (\(failedSessions.count))") {
                    ForEach(failedSessions.sorted { $0.lastActiveAt > $1.lastActiveAt }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session)
                    }
                }
            }
            
            if !archivedSessions.isEmpty {
                Section("Archived (\(archivedSessions.count))") {
                    ForEach(archivedSessions.sorted { $0.completedAt ?? $0.lastActiveAt > $1.completedAt ?? $1.lastActiveAt }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session)
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}

struct DashboardView: View {
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Session metrics
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Overview")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        MetricCard(title: "Total Sessions", value: "\(store.sessions.count)", color: .blue)
                        MetricCard(title: "Processing", value: "\(store.sessions.filter { $0.state == .processing }.count)", color: .orange)
                        MetricCard(title: "Projects", value: "\(store.projects.count)", color: .orange)
                        MetricCard(title: "Queued", value: "\(store.sessions.filter { $0.state == .queued }.count)", color: .blue)
                        MetricCard(title: "Ready for Review", value: "\(store.sessions.filter { $0.state == .readyForReview }.count)", color: .green)
                        MetricCard(title: "Failed", value: "\(store.sessions.filter { $0.state == .failed || $0.state == .error }.count)", color: .red)
                        MetricCard(title: "Archived", value: "\(store.sessions.filter { $0.state == .archived }.count)", color: .brown)
                        MetricCard(title: "High Priority", value: "\(store.sessions.filter { $0.priority == .high || $0.priority == .urgent }.count)", color: .orange)
                    }
                }
                
                // Quick actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Actions")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        Button("Process Next Queued Session") {
                            Task {
                                await store.processNextQueuedSession()
                            }
                        }
                        .disabled(store.sessions.filter { $0.state == .queued }.isEmpty)
                        
                        Button("Archive All Failed Sessions") {
                            Task {
                                await store.archiveAllFailedSessions()
                            }
                        }
                        .disabled(store.sessions.filter { $0.state == .failed || $0.state == .error }.isEmpty)
                        
                        Button("Mark All Ready Sessions as Idle") {
                            Task {
                                await store.markAllReadySessionsAsIdle()
                            }
                        }
                        .disabled(store.sessions.filter { $0.state == .readyForReview }.isEmpty)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct RecentView: View {
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        List(selection: $store.selectedSession) {
            Section("Recent Sessions") {
                ForEach(store.sessions.sorted { $0.lastActiveAt > $1.lastActiveAt }.prefix(10)) { session in
                    SessionRowView(session: session, store: store)
                        .tag(session)
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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

struct SessionRowView: View {
    let session: Session
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        HStack {
            LiveActivityIndicator(state: session.state)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.displayName)
                        .font(.subheadline)
                    
                    // Priority indicator
                    if session.priority != .medium {
                        Image(systemName: session.priority.systemImageName)
                            .foregroundColor(priorityColor(session.priority))
                            .font(.caption)
                    }
                }
                
                HStack {
                    Text(session.state.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let duration = session.actualDuration ?? session.estimatedDuration {
                        Text("• \(session.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !session.tags.isEmpty {
                        Text("• \(session.tags.first ?? "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .onTapGesture {
            store.selectSession(session)
        }
        .contextMenu {
            if session.canQueue {
                Button("Queue Session") {
                    Task {
                        await store.queueSession(session)
                    }
                }
            }
            
            if session.canArchive {
                Button("Archive Session") {
                    Task {
                        await store.archiveSession(session)
                    }
                }
            }
            
            if session.state == .archived {
                Button("Unarchive Session") {
                    Task {
                        await store.unarchiveSession(session)
                    }
                }
            }
            
            Menu("Set Priority") {
                ForEach(SessionPriority.allCases, id: \.self) { priority in
                    Button(priority.displayName) {
                        Task {
                            await store.updateSessionPriority(session, priority: priority)
                        }
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
        return .secondary
    }
    
    private func priorityColor(_ priority: SessionPriority) -> Color {
        switch priority {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
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

#Preview {
    MainView()
}
