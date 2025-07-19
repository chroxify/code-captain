import AppKit
import SwiftUI
import SwiftUIIntrospect

struct ChatView: View {
    let sessionId: UUID
    @ObservedObject var store: CodeCaptainStore
    @State private var messageText = ""

    var body: some View {
        // Get the session directly from the store's published sessions array
        // This ensures we always have the latest session data and SwiftUI can properly track changes
        let session = store.sessions.first { $0.id == sessionId }

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
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.controlBackgroundColor))
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
                    .onChange(of: store.scrollToMessage) { messageId in
                        if let messageId = messageId {
                            Logger.shared.debug(
                                "📜 ChatView received scroll request for message: \(messageId)",
                                category: .ui
                            )
                            // Check if message exists in current session
                            if session.messages.contains(where: {
                                $0.id == messageId
                            }) {
                                Logger.shared.debug(
                                    "✅ Message found in current session, scrolling...",
                                    category: .ui
                                )
                                // Add a longer delay to ensure the view is fully loaded
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.3
                                ) {
                                    // Scroll to the specific message
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        proxy.scrollTo(
                                            messageId,
                                            anchor: .center
                                        )
                                    }
                                    Logger.shared.debug(
                                        "🎯 Scrolled to message",
                                        category: .ui
                                    )
                                }
                            } else {
                                Logger.shared.debug(
                                    "❌ Message not found in current session",
                                    category: .ui
                                )
                            }
                            // Clear the scroll request
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 1.0
                            ) {
                                store.scrollToMessage = nil
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
        )
    }
}

#Preview {
    ChatView(sessionId: UUID(), store: CodeCaptainStore())
}
