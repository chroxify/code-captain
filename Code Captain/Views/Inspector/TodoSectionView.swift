import SwiftUI

struct TodoSectionView: View {
    let session: Session?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (similar to FileChangesOverviewView)
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text("TODOs")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let session = session, session.totalTodosCount > 0 {
                    Text("\(session.completedTodosCount)/\(session.totalTodosCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 2)
            
            // Content
            if let session = session, !session.todos.isEmpty {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(session.todos) { todo in
                        TodoItemView(todo: todo, session: session)
                    }
                }
            } else {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundColor(.green)
                    Text("No TODOs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("TODOs will be extracted from responses")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
    }
}

struct TodoItemView: View {
    let todo: SessionTodo
    let session: Session
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Status indicator (read-only)
            Group {
                if todo.status == .inProgress {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: todo.status.systemImageName)
                        .font(.system(size: 14))
                        .foregroundColor(todo.status == .completed ? .green : .secondary)
                        .frame(width: 16, height: 16)
                }
            }
            
            // Todo content
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.content)
                    .font(.subheadline)
                    .foregroundColor(todo.status == .completed ? .secondary : .primary)
                    .strikethrough(todo.status == .completed)
                    .multilineTextAlignment(.leading)
                
                HStack {
                    // Priority indicator
                    if todo.priority != .medium {
                        Label(todo.priority.displayName, systemImage: todo.priority.systemImageName)
                            .font(.caption2)
                            .foregroundColor(priorityColor(todo.priority))
                    }
                    
                    // Status
                    Text(todo.status.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if todo.status == .completed, let completedAt = todo.completedAt {
                        Text("• \(formatDate(completedAt))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func priorityColor(_ priority: TodoPriority) -> Color {
        switch priority {
        case .low: return .blue
        case .medium: return .secondary
        case .high: return .orange
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
