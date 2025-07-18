import SwiftUI

struct AddProjectView: View {
    @ObservedObject var store: CodeCaptainStore
    @Environment(\.dismiss) private var dismiss
    
    private let logger = Logger.shared
    
    @State private var projectName = ""
    @State private var selectedPath: URL?
    @State private var selectedProvider: ProviderType = .claudeCode
    @State private var isSelectingPath = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Text("New Project")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Create") {
                    createProject()
                }
                .disabled(!isFormValid)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            Form {
                Section(header: Text("Project Details")) {
                    HStack {
                        Text("Project Name")
                            .frame(minWidth: 120, alignment: .leading)
                        
                        TextField("Enter project name", text: $projectName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Provider")
                            .frame(minWidth: 120, alignment: .leading)
                        
                        Picker("", selection: $selectedProvider) {
                            // Only show Claude Code for now
                            Label(ProviderType.claudeCode.displayName, systemImage: ProviderType.claudeCode.systemImageName)
                                .tag(ProviderType.claudeCode)
                            
                            // Disabled options for future providers
                            Label(ProviderType.openCode.displayName, systemImage: ProviderType.openCode.systemImageName)
                                .tag(ProviderType.openCode)
                                .disabled(true)
                            
                            Label(ProviderType.custom.displayName, systemImage: ProviderType.custom.systemImageName)
                                .tag(ProviderType.custom)
                                .disabled(true)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Section(header: Text("Project Location")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Selected Path:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Choose Folder") {
                                selectProjectPath()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if let path = selectedPath {
                            Text(path.path)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                        } else {
                            Text("No path selected")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Section(header: Text("Provider Status")) {
                    HStack {
                        Image(systemName: selectedProvider.systemImageName)
                            .foregroundColor(providerStatusColor)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedProvider.displayName)
                                .font(.headline)
                            
                            Text(providerStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(providerStatusColor)
                            .frame(width: 10, height: 10)
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var isFormValid: Bool {
        !projectName.isEmpty && selectedPath != nil && store.isProviderAvailable(selectedProvider)
    }
    
    private var providerStatusColor: Color {
        store.isProviderAvailable(selectedProvider) ? .green : .red
    }
    
    private var providerStatusText: String {
        store.isProviderAvailable(selectedProvider) ? "Available" : "Not Available"
    }
    
    private func selectProjectPath() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.prompt = "Select Project Folder"
        
        if panel.runModal() == .OK {
            selectedPath = panel.url
            
            // Auto-generate project name from folder name if empty
            if projectName.isEmpty, let folderName = panel.url?.lastPathComponent {
                projectName = folderName
            }
        }
    }
    
    private func createProject() {
        logger.logFunctionEntry(category: .ui)
        logger.info("User initiated project creation: '\(projectName)'", category: .ui)
        
        guard let path = selectedPath else { 
            logger.error("No path selected for project creation", category: .ui)
            return 
        }
        
        logger.debug("Creating project with path: \(path.path), provider: \(selectedProvider)", category: .ui)
        
        Task {
            logger.debug("Calling store.addProject", category: .ui)
            await store.addProject(
                name: projectName,
                path: path,
                providerType: selectedProvider
            )
            
            if store.error == nil {
                logger.info("Project creation successful, dismissing view", category: .ui)
                dismiss()
            } else {
                logger.error("Project creation failed with error: \(store.error ?? "Unknown error")", category: .ui)
            }
        }
        
        logger.logFunctionExit(category: .ui)
    }
}

#Preview {
    AddProjectView(store: CodeCaptainStore())
}