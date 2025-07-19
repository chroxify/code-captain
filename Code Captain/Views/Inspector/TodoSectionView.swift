import SwiftUI

struct TodoSectionView: View {
    let session: Session?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("TODOs")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let session = session {
                    Text("\(session.completedTodosCount)/\(session.totalTodosCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Content
            ScrollView {
                if let session = session, !session.todos.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(session.todos) { todo in
                            TodoItemView(todo: todo, session: session)
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No TODOs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("TODOs will be extracted from agent responses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
        }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .cornerRadius(6)
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
