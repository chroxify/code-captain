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

#Preview {
    MainView()
}