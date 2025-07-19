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
                .toolbar {
                    Spacer()
                    Button(action: {
                        showingAddSession = true
                    }) {
                        Image(systemName: "rectangle.stack.badge.plus")
                    }
                    .help("New Session")
                }
        } detail: {
            DetailView(
                store: store,
                isInspectorPresented: $isInspectorPresented
            )
        }
        .inspector(isPresented: $isInspectorPresented) {
            InspectorView(
                session: store.selectedSession,
                store: store,
                isInspectorPresented: $isInspectorPresented
            )
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
            ToolbarItem(placement: .navigation) {
                // Consistent layout container to prevent positioning jumps
                HStack(alignment: .center, spacing: 8) {
                    if let session = store.selectedSession {
                        LiveActivityIndicator(state: session.state).scaleEffect(
                            1.1
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            // Session name (top row)
                            Text(session.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .fixedSize(horizontal: true, vertical: false)
                                .lineLimit(1)

                            // Project, status, and todos (bottom row)
                            HStack(spacing: 4) {
                                // Project name
                                if let project = store.projects.first(where: {
                                    $0.id == session.projectId
                                }) {
                                    Text(project.displayName)
                                        .font(
                                            .system(size: 11, weight: .regular)
                                        )
                                        .foregroundColor(.secondary)
                                        .animation(
                                            .none,
                                            value: project.displayName
                                        )

                                    Text("•")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                // Status
                                Text(session.state.displayName)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(
                                        colorForState(session.state)
                                    )
                                    .animation(.none, value: session.state)

                                // Todo count if todos exist
                                if !session.todos.isEmpty {
                                    Text(
                                        "• \(session.completedTodosCount)/\(session.totalTodosCount)"
                                    )
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.secondary)
                                }
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    } else {
                        // Invisible placeholder to maintain consistent positioning
                        VStack(alignment: .leading, spacing: 2) {
                            Text("")
                                .font(.system(size: 12, weight: .medium))

                            HStack(spacing: 4) {
                                Text("")
                                    .font(.system(size: 11, weight: .regular))
                            }
                        }
                        .opacity(0)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .animation(.none, value: store.selectedSession?.id)
            }

            ToolbarItem(placement: .principal) {
                Color.clear
            }

            ToolbarItemGroup(placement: .automatic) {
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
