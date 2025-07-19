import SwiftUI

struct SessionRowView: View {
    let session: Session
    @ObservedObject var store: CodeCaptainStore
    let searchText: String?
    let matchingMessage: Message?
    
    init(session: Session, store: CodeCaptainStore, searchText: String? = nil, matchingMessage: Message? = nil) {
        self.session = session
        self.store = store
        self.searchText = searchText
        self.matchingMessage = matchingMessage
    }
    
    var body: some View {
        HStack {
            LiveActivityIndicator(state: session.state)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.displayName)
                        .font(.subheadline)
                    
                    // Priority indicator
                    if session.priority != .none {
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
                    Button(action: {
                        Task {
                            await store.updateSessionPriority(session, priority: priority)
                        }
                    }) {
                        Label(priority.displayName, systemImage: session.priority == priority ? "checkmark" : "")
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
        .onChange(of: store.selectedSessionId) { selectedId in
            // If this session was just selected and we have a matching message, scroll to it
            if selectedId == session.id, let matchingMessage = matchingMessage {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    Logger.shared.debug("🔍 Setting scroll to message: \(matchingMessage.content.prefix(50))...", category: .ui)
                    store.scrollToMessage = matchingMessage.id
                }
            }
        }
    }
    
    private func colorForState(_ state: SessionState) -> Color {
        return .secondary
    }
    
    private func priorityColor(_ priority: SessionPriority) -> Color {
        switch priority {
        case .none: return .secondary
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .urgent: return .red
        }
    }
}
