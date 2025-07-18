import SwiftUI

struct SessionsView: View {
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        List(selection: $store.selectedSessionId) {
            let processingSessions = store.sessions.filter { $0.state == .processing }
            let waitingForInputSessions = store.sessions.filter { $0.state == .waitingForInput }
            let readyForReviewSessions = store.sessions.filter { $0.state == .readyForReview }
            let queuedSessions = store.sessions.filter { $0.state == .queued }
            let idleSessions = store.sessions.filter { $0.state == .idle }
            let failedSessions = store.sessions.filter { $0.state == .failed || $0.state == .error }
            let archivedSessions = store.sessions.filter { $0.state == .archived }
            
            if !processingSessions.isEmpty {
                Section {
                    ForEach(processingSessions.sorted { $0.priority.rawValue > $1.priority.rawValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    HStack {
                        Text("Processing")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .medium))
                        Text("\(processingSessions.count)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .regular))
                    }
                }
            }
            
            if !waitingForInputSessions.isEmpty {
                Section {
                    ForEach(waitingForInputSessions.sorted { $0.priority.rawValue > $1.priority.rawValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    HStack {
                        Text("Waiting for Input")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .medium))
                        Text("\(waitingForInputSessions.count)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .regular))
                    }
                }
            }
            
            if !readyForReviewSessions.isEmpty {
                Section {
                    ForEach(readyForReviewSessions.sorted { $0.priority.rawValue > $1.priority.rawValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    HStack {
                        Text("Ready for Review")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .medium))
                        Text("\(readyForReviewSessions.count)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .regular))
                    }
                }
            }
            
            if !queuedSessions.isEmpty {
                Section {
                    ForEach(queuedSessions.sorted { $0.priority.rawValue > $1.priority.rawValue }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    HStack {
                        Text("Queued")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .medium))
                        Text("\(queuedSessions.count)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .regular))
                    }
                }
            }
            
            if !idleSessions.isEmpty {
                Section {
                    ForEach(idleSessions.sorted { $0.lastActiveAt > $1.lastActiveAt }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    HStack {
                        Text("Idle")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .medium))
                        Text("\(idleSessions.count)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .regular))
                    }
                }
            }
            
            if !failedSessions.isEmpty {
                Section {
                    ForEach(failedSessions.sorted { $0.lastActiveAt > $1.lastActiveAt }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    HStack {
                        Text("Failed")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .medium))
                        Text("\(failedSessions.count)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .regular))
                    }
                }
            }
            
            if !archivedSessions.isEmpty {
                Section {
                    ForEach(archivedSessions.sorted { $0.completedAt ?? $0.lastActiveAt > $1.completedAt ?? $1.lastActiveAt }) { session in
                        SessionRowView(session: session, store: store)
                            .tag(session.id)
                    }
                } header: {
                    HStack {
                        Text("Archived")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .medium))
                        Text("\(archivedSessions.count)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, weight: .regular))
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}