import SwiftUI

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
                    .disabled(true)  // Placeholder for future functionality

                    Button(action: {}) {
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true)  // Placeholder for future functionality

                    Button(action: {}) {
                        Image(systemName: "hammer")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true)  // Placeholder for future functionality

                    Button(action: {}) {
                        Image(
                            systemName:
                                "arrow.up.and.down.and.arrow.left.and.right"
                        )
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true)  // Placeholder for future functionality
                }

                // Text input container
                HStack(spacing: 8) {
                    TextField(
                        placeholderText,
                        text: $messageText,
                        axis: .vertical
                    )
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
                                    .fill(
                                        canSendMessage
                                            ? Color.accentColor
                                            : Color.secondary
                                    )
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
                                .stroke(
                                    Color(NSColor.separatorColor),
                                    lineWidth: 1
                                )
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
                    .disabled(true)  // Placeholder for future functionality

                    Button(action: {}) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(true)  // Placeholder for future functionality
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