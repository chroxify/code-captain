import SwiftUI

struct ChatView: View {
    let sessionId: UUID
    @ObservedObject var store: CodeCaptainStore
    @State private var messageText = ""
    @State private var isInspectorPresented = true
    
    private var session: Session? {
        store.getSession(by: sessionId)
    }
    
    var body: some View {
        guard let session = session else {
            return AnyView(
                VStack {
                    Text("Session not found")
                        .foregroundColor(.red)
                }
            )
        }
        
        return AnyView(
            VStack(spacing: 0) {
                // Header
                ChatHeaderView(session: session, store: store)
                
                Divider()
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(session.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        if let lastMessage = session.messages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: session.messages.count) {
                        if let lastMessage = session.messages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input
                ChatInputView(
                    messageText: $messageText,
                    session: session,
                    store: store
                )
            }
            .navigationTitle(session.displayName)
            .inspector(isPresented: $isInspectorPresented) {
                // Use the exact same VSplitView content as RightSidebarView
                VSplitView {
                    // Top section: TODOs (50%) - exact same as before
                    TodoSectionView(session: session)
                        .frame(minHeight: 150)
                    
                    // Bottom section: Terminal (50%) - exact same as before
                    SwiftTerminalSectionView(session: session, store: store)
                        .frame(minHeight: 150)
                }
                .inspectorColumnWidth(min: 250, ideal: 300, max: 450)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        isInspectorPresented.toggle()
                    }) {
                        Image(systemName: "sidebar.right")
                            .help(isInspectorPresented ? "Hide Inspector" : "Show Inspector")
                    }
                }
            }
        )
    }
}

struct ChatHeaderView: View {
    let session: Session?
    @ObservedObject var store: CodeCaptainStore
    
    var body: some View {
        guard let session = session else {
            return AnyView(
                HStack {
                    Text("Session not found")
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            )
        }
        
        return AnyView(
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: session.state.systemImageName)
                            .foregroundColor(colorForState(session.state))
                        
                        Text(session.displayName)
                            .font(.headline)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(session.state.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let project = store.projects.first(where: { $0.id == session.projectId }) {
                        Text(project.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 12) {
                    if session.state == .active {
                        Button(action: {
                            Task {
                                await store.pauseSession(session)
                            }
                        }) {
                            Image(systemName: "pause.circle")
                                .font(.title2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Pause session")
                        
                        Button(action: {
                            Task {
                                await store.stopSession(session)
                            }
                        }) {
                            Image(systemName: "stop.circle")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Stop session")
                        
                    } else if session.state == .paused {
                        Button(action: {
                            Task {
                                await store.resumeSession(session)
                            }
                        }) {
                            Image(systemName: "play.circle")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Resume session")
                        
                    } else if session.canStart {
                        Button(action: {
                            Task {
                                await store.startSession(session)
                            }
                        }) {
                            Image(systemName: "play.circle")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Start session")
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private func colorForState(_ state: SessionState) -> Color {
        switch state {
        case .idle: return .secondary
        case .starting: return .orange
        case .active: return .green
        case .paused: return .yellow
        case .stopping: return .orange
        case .error: return .red
        }
    }
}

struct MessageBubbleView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 8) {
                HStack {
                    if !message.isFromUser {
                        Image(systemName: "terminal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(message.role.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.displayContent)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.isFromUser 
                            ? Color.accentColor.opacity(0.1)
                            : Color(NSColor.controlBackgroundColor)
                    )
                    .cornerRadius(16)
                
                // Metadata
                if let metadata = message.metadata {
                    MessageMetadataView(metadata: metadata)
                }
            }
            
            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
    }
}

struct MessageMetadataView: View {
    let metadata: MessageMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let filesChanged = metadata.filesChanged, !filesChanged.isEmpty {
                Label("Files: \(filesChanged.joined(separator: ", "))", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let gitOps = metadata.gitOperations, !gitOps.isEmpty {
                Label("Git: \(gitOps.joined(separator: ", "))", systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let tools = metadata.toolsUsed, !tools.isEmpty {
                Label("Tools: \(tools.joined(separator: ", "))", systemImage: "wrench")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

struct ChatInputView: View {
    @Binding var messageText: String
    let session: Session
    @ObservedObject var store: CodeCaptainStore
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Left action buttons
                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true) // Placeholder for future functionality
                    
                    Button(action: {}) {
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true) // Placeholder for future functionality
                    
                    Button(action: {}) {
                        Image(systemName: "hammer")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true) // Placeholder for future functionality
                    
                    Button(action: {}) {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true) // Placeholder for future functionality
                }
                
                // Text input container
                HStack(spacing: 8) {
                    TextField(placeholderText, text: $messageText, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .lineLimit(1...6)
                        .font(.system(size: 14))
                        .onSubmit {
                            sendMessage()
                        }
                        .disabled(!canTypeMessage)
                    
                    // Send button
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(canSendMessage ? Color.accentColor : Color.secondary)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canSendMessage)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                )
                
                // Right action buttons
                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "mic")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true) // Placeholder for future functionality
                    
                    Button(action: {}) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true) // Placeholder for future functionality
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private var canTypeMessage: Bool {
        // Allow typing even if session isn't active, but show appropriate state
        return true
    }
    
    private var placeholderText: String {
        switch session.state {
        case .idle:
            return "Click start to begin session"
        case .starting:
            return "Starting Claude Code..."
        case .active:
            return "Message"
        case .stopping:
            return "Stopping session..."
        case .paused:
            return "Session paused - resume to send messages"
        case .error:
            return "Session error - check logs"
        }
    }
    
    private var canSendMessage: Bool {
        let hasText = !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let sessionReady = session.isActive || session.state == .starting
        
        return hasText && sessionReady
    }
    
    private func sendMessage() {
        guard canSendMessage else { return }
        
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        
        Task {
            await store.sendMessage(message, to: session)
        }
    }
}


struct TodoSectionView: View {
    let session: Session?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("TODOs")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TODOs will be extracted from Claude responses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// Old terminal implementation removed - now using SwiftTerminalSectionView with SwiftTerm

#Preview {
    ChatView(sessionId: UUID(), store: CodeCaptainStore())
}