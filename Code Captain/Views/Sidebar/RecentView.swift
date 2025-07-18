import SwiftUI

struct RecentView: View {
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        List(selection: $store.selectedSessionId) {
            Section("Recent Sessions") {
                ForEach(store.sessions.sorted { $0.lastActiveAt > $1.lastActiveAt }.prefix(10)) { session in
                    SessionRowView(session: session, store: store)
                        .tag(session.id)
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}