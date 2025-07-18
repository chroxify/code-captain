import SwiftUI

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
            .padding(.top, 8)
        }
        .navigationTitle("Code Captain")
    }
}