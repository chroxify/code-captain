import SwiftUI

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