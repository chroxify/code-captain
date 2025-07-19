import AppKit
import SwiftUI

struct SessionsView: View {
    @ObservedObject var store: CodeCaptainStore
    let searchText: String
    @State private var isArchivedExpanded = false
    @State private var isArchivedHovered = false

    var filteredSessions: [Session] {
        if searchText.isEmpty {
            return store.sessions
        }

        return store.sessions.filter { session in
            // Search in session name
            if session.displayName.localizedCaseInsensitiveContains(searchText)
            {
                return true
            }

            // Search in messages
            if session.messages.contains(where: { message in
                message.content.localizedCaseInsensitiveContains(searchText)
            }) {
                return true
            }

            // Search in todos
            if session.todos.contains(where: { todo in
                todo.content.localizedCaseInsensitiveContains(searchText)
            }) {
                return true
            }

            // Search in project name
            if let project = store.projects.first(where: {
                $0.id == session.projectId
            }) {
                if project.displayName.localizedCaseInsensitiveContains(
                    searchText
                ) {
                    return true
                }
            }

            return false
        }
    }

    func findMatchingMessage(in session: Session) -> Message? {
        return session.messages.first { message in
            message.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        FloatingSidebarScroll {
            List(selection: $store.selectedSessionId) {
                let processingSessions = filteredSessions.filter {
                    $0.state == .processing
                }
                let waitingForInputSessions = filteredSessions.filter {
                    $0.state == .waitingForInput
                }
                let readyForReviewSessions = filteredSessions.filter {
                    $0.state == .readyForReview
                }
                let queuedSessions = filteredSessions.filter {
                    $0.state == .queued
                }
                let idleSessions = filteredSessions.filter { $0.state == .idle }
                let failedSessions = filteredSessions.filter {
                    $0.state == .failed || $0.state == .error
                }
                let archivedSessions = filteredSessions.filter {
                    $0.state == .archived
                }

                if !waitingForInputSessions.isEmpty {
                    Section {
                        ForEach(
                            waitingForInputSessions.sorted {
                                $0.priority.priorityValue
                                    > $1.priority.priorityValue
                            }
                        ) { session in
                            SessionRowView(
                                session: session,
                                store: store,
                                searchText: searchText.isEmpty
                                    ? nil : searchText,
                                matchingMessage: searchText.isEmpty
                                    ? nil : findMatchingMessage(in: session)
                            )
                            .tag(session.id)
                        }
                    } header: {
                        SectionHeaderView(
                            title: "Waiting for Input",
                            count: waitingForInputSessions.count
                        )
                    }
                }

                if !readyForReviewSessions.isEmpty {
                    Section {
                        ForEach(
                            readyForReviewSessions.sorted {
                                $0.priority.priorityValue
                                    > $1.priority.priorityValue
                            }
                        ) { session in
                            SessionRowView(
                                session: session,
                                store: store,
                                searchText: searchText.isEmpty
                                    ? nil : searchText,
                                matchingMessage: searchText.isEmpty
                                    ? nil : findMatchingMessage(in: session)
                            )
                            .tag(session.id)
                        }
                    } header: {
                        SectionHeaderView(
                            title: "Ready for Review",
                            count: readyForReviewSessions.count
                        )
                    }
                }

                if !processingSessions.isEmpty {
                    Section {
                        ForEach(
                            processingSessions.sorted {
                                $0.priority.priorityValue
                                    > $1.priority.priorityValue
                            }
                        ) { session in
                            SessionRowView(
                                session: session,
                                store: store,
                                searchText: searchText.isEmpty
                                    ? nil : searchText,
                                matchingMessage: searchText.isEmpty
                                    ? nil : findMatchingMessage(in: session)
                            )
                            .tag(session.id)
                        }
                    } header: {
                        SectionHeaderView(
                            title: "Processing",
                            count: processingSessions.count
                        )
                    }
                }

                if !queuedSessions.isEmpty {
                    Section {
                        ForEach(
                            queuedSessions.sorted {
                                $0.priority.priorityValue
                                    > $1.priority.priorityValue
                            }
                        ) { session in
                            SessionRowView(
                                session: session,
                                store: store,
                                searchText: searchText.isEmpty
                                    ? nil : searchText,
                                matchingMessage: searchText.isEmpty
                                    ? nil : findMatchingMessage(in: session)
                            )
                            .tag(session.id)
                        }
                    } header: {
                        SectionHeaderView(
                            title: "Queued",
                            count: queuedSessions.count
                        )
                    }
                }

                if !idleSessions.isEmpty {
                    Section {
                        ForEach(
                            idleSessions.sorted {
                                $0.lastActiveAt > $1.lastActiveAt
                            }
                        ) { session in
                            SessionRowView(
                                session: session,
                                store: store,
                                searchText: searchText.isEmpty
                                    ? nil : searchText,
                                matchingMessage: searchText.isEmpty
                                    ? nil : findMatchingMessage(in: session)
                            )
                            .tag(session.id)
                        }
                    } header: {
                        SectionHeaderView(
                            title: "Idle",
                            count: idleSessions.count
                        )
                    }
                }

                if !failedSessions.isEmpty {
                    Section {
                        ForEach(
                            failedSessions.sorted {
                                $0.lastActiveAt > $1.lastActiveAt
                            }
                        ) { session in
                            SessionRowView(
                                session: session,
                                store: store,
                                searchText: searchText.isEmpty
                                    ? nil : searchText,
                                matchingMessage: searchText.isEmpty
                                    ? nil : findMatchingMessage(in: session)
                            )
                            .tag(session.id)
                        }
                    } header: {
                        SectionHeaderView(
                            title: "Failed",
                            count: failedSessions.count
                        )
                    }
                }

                if !archivedSessions.isEmpty {
                    Section(isExpanded: $isArchivedExpanded) {
                        ForEach(
                            archivedSessions.sorted {
                                $0.completedAt ?? $0.lastActiveAt > $1
                                    .completedAt
                                    ?? $1.lastActiveAt
                            }
                        ) { session in
                            SessionRowView(
                                session: session,
                                store: store,
                                searchText: searchText.isEmpty
                                    ? nil : searchText,
                                matchingMessage: searchText.isEmpty
                                    ? nil : findMatchingMessage(in: session)
                            )
                            .tag(session.id)
                        }
                    } header: {
                        SectionHeaderView(
                            title: "Archived",
                            count: archivedSessions.count
                        )
                        .opacity(0.5)
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}
