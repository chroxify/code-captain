import SwiftUI

enum SidebarViewType: String, CaseIterable {
    case sessions = "Agents"
    
    var systemImageName: String {
        switch self {
        case .sessions: return "brain"
        }
    }
    
    var filledSystemImageName: String {
        switch self {
        case .sessions: return "brain.fill"
        }
    }
}

struct SidebarViewToggle: View {
    @Binding var currentView: SidebarViewType
    
    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
            
            HStack(spacing: 12) {
                ForEach(SidebarViewType.allCases, id: \.self) { view in
                    Button(action: {
                        currentView = view
                    }) {
                        Image(systemName: currentView == view ? view.filledSystemImageName : view.systemImageName)
                            .font(.system(size: view == .sessions ? 12 : 13, weight: .medium))
                            .foregroundColor(currentView == view ? .accentColor : .secondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(view.rawValue)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Rectangle())
        }
    }
}