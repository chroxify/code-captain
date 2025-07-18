import SwiftUI

enum SidebarViewType: String, CaseIterable {
    case projects = "Projects"
    case sessions = "Agents"
    case dashboard = "Dashboard"
    case recent = "Recent"
    
    var systemImageName: String {
        switch self {
        case .projects: return "folder"
        case .sessions: return "brain"
        case .dashboard: return "gauge"
        case .recent: return "clock"
        }
    }
    
    var filledSystemImageName: String {
        switch self {
        case .projects: return "folder.fill"
        case .sessions: return "brain.fill"
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .recent: return "clock.fill"
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