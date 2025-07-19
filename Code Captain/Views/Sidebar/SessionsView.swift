import SwiftUI

struct SessionsView: View {
    @ObservedObject var store: CodeCaptainStore
    @State private var isArchivedExpanded = false
    @State private var isArchivedHovered = false
    
    var body: some View {
        List(selection: $store.selectedSessionId) {
            let processingSessions = store.sessions.filter { $0.state == .processing }
            let waitingForInputSessions = store.sessions.filter { $0.state == .waitingForInput }
            let readyForReviewSessions = store.sessions.filter { $0.state == .readyForReview }
            let queuedSessions = store.sessions.filter { $0.state == .queued }
            let idleSessions = store.sessions.filter { $0.state == .idle }
            let failedSessions = store.sessions.filter { $0.state == .failed || $0.state == .error }
            let archivedSessions = store.sessions.filter { $0.state == .archived }
            
            if !waitingForInputSessions.isEmpty {
                Section {
                    ForEach(waitingForInputSessions.sorted { $0.priority.priorityValue > $1.priority.priorityValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    SectionHeaderView(title: "Waiting for Input", count: waitingForInputSessions.count)
                }
            }
            
            if !readyForReviewSessions.isEmpty {
                Section {
                    ForEach(readyForReviewSessions.sorted { $0.priority.priorityValue > $1.priority.priorityValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    SectionHeaderView(title: "Ready for Review", count: readyForReviewSessions.count)
                }
            }
            
            if !processingSessions.isEmpty {
                Section {
                    ForEach(processingSessions.sorted { $0.priority.priorityValue > $1.priority.priorityValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    SectionHeaderView(title: "Processing", count: processingSessions.count)
                }
            }
            
            if !queuedSessions.isEmpty {
                Section {
                    ForEach(queuedSessions.sorted { $0.priority.priorityValue > $1.priority.priorityValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    SectionHeaderView(title: "Queued", count: queuedSessions.count)
                }
            }
            
            if !idleSessions.isEmpty {
                Section {
                    ForEach(idleSessions.sorted { $0.lastActiveAt > $1.lastActiveAt }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    SectionHeaderView(title: "Idle", count: idleSessions.count)
                }
            }
            
            if !failedSessions.isEmpty {
                Section {
                    ForEach(failedSessions.sorted { $0.lastActiveAt > $1.lastActiveAt }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    SectionHeaderView(title: "Failed", count: failedSessions.count)
                }
            }
            
            if !archivedSessions.isEmpty {
                Section(isExpanded: $isArchivedExpanded) {
                    ForEach(archivedSessions.sorted { $0.completedAt ?? $0.lastActiveAt > $1.completedAt ?? $1.lastActiveAt }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    SectionHeaderView(title: "Archived", count: archivedSessions.count)
                        .opacity(0.5)
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}
