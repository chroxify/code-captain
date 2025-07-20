import SwiftUI

enum ChatMode: String, CaseIterable {
    case chat = "Chat"
    case plan = "Plan"
    case ask = "Ask"
    
    var icon: String {
        switch self {
        case .chat:
            return "bubble.left"
        case .plan:
            return "list.bullet.clipboard"
        case .ask:
            return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .chat:
            return Color(NSColor.textColor)
        case .plan:
            return Color(red: 0.0, green: 0.8, blue: 0.4) // Vibrant emerald green
        case .ask:
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Rich amber orange
        }
    }
    
    var placeholder: String {
        switch self {
        case .chat:
            return "Send a message or describe what you need help with..."
        case .plan:
            return "Write a plan to execute your task..."
        case .ask:
            return "Ask any question about your code or project..."
        }
    }
}

struct ChatInputView: View {
    @Binding var messageText: String
    let session: Session
    @ObservedObject var store: CodeCaptainStore
    @FocusState private var isTextFieldFocused: Bool
    @State private var isMicHovered = false
    @State private var currentMode: ChatMode = .chat
    @State private var isDropdownOpen = false

    var body: some View {
        VStack(spacing: 12) {
            // Text input container
            HStack(spacing: 8) {
                TextField(
                    currentMode.placeholder,
                    text: $messageText,
                    axis: .vertical
                )
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isTextFieldFocused)
                .lineLimit(1...10)
                .font(.system(size: 14))
                .submitLabel(.send)
                .onSubmit {
                    // Only submit if not holding shift
                    if NSEvent.modifierFlags.contains(.shift) == false {
                        sendMessage()
                    }
                }
                .onKeyPress { keyPress in
                    if keyPress.key == .return && keyPress.modifiers.contains(.shift) {
                        // Add newline manually for Shift+Enter
                        messageText += "\n"
                        return .handled
                    }
                    return .ignored
                }
                .disabled(!canTypeMessage)
            }

            // Right action buttons
            HStack(spacing: 8) {
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "mic")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.highlightColor))
                                .opacity(isMicHovered ? 0.1 : 0)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isMicHovered = hovering
                    }
                }

                // Primary send button with dropdown
                HStack(spacing: 0) {
                    // Left side - Send action (full area clickable)
                    Button(action: sendMessage) {
                        HStack {
                            Text(currentMode.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(NSColor.controlBackgroundColor))
                            Spacer()
                        }
                        .padding(.leading, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canSendMessage)
                    
                    // Vertical separator
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.2))
                        .frame(width: 1.5, height: 16)
                    
                    // Right side - Dropdown (full area clickable)
                    ZStack {
                        // Invisible menu for functionality
                        Menu {
                            ForEach(ChatMode.allCases, id: \.rawValue) { mode in
                                Button(action: {
                                    currentMode = mode
                                }) {
                                    HStack {
                                        if currentMode == mode {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(mode == .chat ? nil : mode.color)
                                        }
                                        if mode == .chat {
                                            Label(mode.rawValue, systemImage: mode.icon)
                                        } else {
                                            Label {
                                                Text(mode.rawValue)
                                                    .foregroundStyle(mode.color)
                                            } icon: {
                                                Image(systemName: mode.icon)
                                                    .foregroundStyle(mode.color)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        } label: {
                            Color.clear
                                .frame(height: 36)
                                .contentShape(Rectangle())
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        .menuIndicator(.hidden)
                        
                        // Visible chevron overlay
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(NSColor.controlBackgroundColor))
                            Spacer()
                        }
                        .opacity(canSendMessage ? 1 : 0.5)
                        .padding(.trailing, 4)
                        .allowsHitTesting(false)
                    }
                    .disabled(!canSendMessage)
                }
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    Capsule()
                        .fill(canSendMessage ? currentMode.color : Color(NSColor.disabledControlTextColor))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            Color(NSColor.separatorColor).opacity(0.5),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 4)
        )
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
            return "Message"
        case .processing:
            return "Processing..."
        case .waitingForInput:
            return "Waiting for your input"
        case .readyForReview:
            return "Ready - send next message"
        case .error:
            return "Session error - check logs"
        case .queued:
            return "Session queued - waiting to start"
        case .archived:
            return "Session archived - unarchive to send messages"
        case .failed:
            return "Session failed - check logs"
        }
    }

    private var canSendMessage: Bool {
        let hasText = !messageText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
        let sessionReady = session.canSendMessage

        return hasText && sessionReady
    }

    private func sendMessage() {
        guard canSendMessage else { return }

        let message = messageText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        messageText = ""

        Task {
            // Use streaming if available
            if session.canSendMessage {
                let messageStream = store.sendMessageStream(
                    message,
                    to: session
                )
                for await streamedMessage in messageStream {
                    Logger.shared.debug(
                        "Received streamed message: \(streamedMessage.id)",
                        category: .communication
                    )
                    // The message is already added to the session in the stream
                    // UI will update automatically via @Published sessions
                }
            } else {
                // Fallback to regular message sending
                await store.sendMessage(message, to: session)
            }
        }
    }
}
