import AppKit
import SwiftUI

struct ChatView: View {
    let sessionId: UUID
    @ObservedObject var store: CodeCaptainStore
    @State private var messageText = ""
    @State private var isUserNearBottom = true
    @State private var lastMessageCount = 0

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
                    FloatingScrollView(background: .color(NSColor.controlBackgroundColor)) {
                        ScrollView {
                            VStack(spacing: 0) {
                                LazyVStack(spacing: 16) {
                                    ForEach(session.messages) { message in
                                        MessageBubbleView(message: message)
                                            .id(message.id)
                                    }
                                }
                                .padding()

                                // Bottom anchor with extra spacing - positioned after the padding
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: 16)
                                    .id("bottom-anchor")
                            }
                        }
                        .onScrollGeometryChange(for: Bool.self) { geometry in
                            // Check if user is in the last 20% of the scrollable content
                            let scrollableHeight = max(
                                0,
                                geometry.contentSize.height
                                    - geometry.containerSize.height
                            )
                            let currentScrollPosition = max(
                                0,
                                geometry.contentOffset.y
                            )

                            // If there's no scrollable content, user is always "at bottom"
                            guard scrollableHeight > 0 else { return true }

                            let bottomThreshold = scrollableHeight * 0.8  // Last 20% of content
                            let isInBottomSection =
                                currentScrollPosition >= bottomThreshold

                            // Debug logging
                            Logger.shared.debug(
                                "📊 Scroll: content=\(geometry.contentSize.height), container=\(geometry.containerSize.height), scrollable=\(scrollableHeight), position=\(currentScrollPosition), threshold=\(bottomThreshold), inBottom=\(isInBottomSection)",
                                category: .ui
                            )

                            return isInBottomSection
                        } action: { oldValue, newValue in
                            Logger.shared.debug(
                                "🔄 Scroll state changed: \(oldValue) → \(newValue)",
                                category: .ui
                            )
                            if isUserNearBottom != newValue {
                                isUserNearBottom = newValue
                                Logger.shared.debug(
                                    "👤 User near bottom updated to: \(newValue)",
                                    category: .ui
                                )
                            }
                        }
                        .onAppear {
                            // Always scroll to bottom with padding visible on appear
                            DispatchQueue.main.async {
                                proxy.scrollTo("bottom-anchor", anchor: .bottom)
                                lastMessageCount = session.messages.count
                            }
                        }
                        .onChange(of: session.messages.count) {
                            let currentCount = session.messages.count

                            Logger.shared.debug(
                                "📝 Message count: \(lastMessageCount) → \(currentCount), userNearBottom: \(isUserNearBottom)",
                                category: .ui
                            )

                            // Only auto-scroll if user is near the bottom (following the conversation)
                            // Don't auto-scroll just because count increased - user might be reading history
                            if isUserNearBottom {
                                Logger.shared.debug(
                                    "✅ Auto-scrolling because user is near bottom",
                                    category: .ui
                                )
                                DispatchQueue.main.async {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(
                                            "bottom-anchor",
                                            anchor: .bottom
                                        )
                                    }
                                }
                            } else {
                                Logger.shared.debug(
                                    "❌ Not auto-scrolling - user is reading history",
                                    category: .ui
                                )
                            }

                            lastMessageCount = currentCount
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
                                        withAnimation(.easeInOut(duration: 0.5))
                                        {
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
