import SwiftUI

struct InspectorView: View {
    let session: Session?
    @ObservedObject var store: CodeCaptainStore
    @Binding var isInspectorPresented: Bool
    
    var body: some View {
        if let session = session {
            VStack(spacing: 0) {
                // Separator below toolbar
                Divider()
                
                // Main content area
                VSplitView {
                    // Top section: TODOs (50%)
                    TodoSectionView(session: session)
                        .frame(minHeight: 150)
                    
                    // Bottom section: Terminal (50%)
                    SwiftTerminalSectionView(session: session, store: store)
                        .frame(minHeight: 150)
                }
            }
            .inspectorColumnWidth(min: 250, ideal: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("", systemImage: "sidebar.right") {
                        isInspectorPresented.toggle()
                    }
                    .help("Toggle Inspector")
                }
            }
        } else {
            VStack(spacing: 0) {
                // Separator below toolbar
                Divider()
                
                // Main content area
                VStack {
                    Text("No Session Selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Select a session to view tools and terminal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .inspectorColumnWidth(min: 250, ideal: 300, max: 450)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("", systemImage: "sidebar.right") {
                        isInspectorPresented.toggle()
                    }
                    .help("Toggle Inspector")
                }
            }
        }
    }
}
