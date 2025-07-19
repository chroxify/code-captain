import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: CodeCaptainStore
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                HStack {
//                    Image(systemName: "magnifyingglass")
//                        .foregroundColor(.secondary)
//                        .font(.system(size: 13))

                    TextField(
                        "Search agents, todos...",
                        text: $searchText
                    )
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13))

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Color(NSColor.controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 6)
                )
            }
            .padding(.horizontal, 10)

            // Sessions content
            SessionsView(store: store, searchText: searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 8)
        }
        .navigationTitle("Code Captain")
    }
}
