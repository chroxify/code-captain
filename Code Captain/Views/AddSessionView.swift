import SwiftUI

struct AddSessionView: View {
    @ObservedObject var store: CodeCaptainStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var sessionName = ""
    @State private var selectedProject: Project?
    @State private var startImmediately = true
    @State private var providerVersion: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Text("New Session")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Create") {
                    createSession()
                }
                .disabled(!isFormValid)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            Form {
                Section(header: Text("Session Details")) {
                    TextField("Session Name", text: $sessionName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Project", selection: $selectedProject) {
                        Text("Select a project...")
                            .tag(nil as Project?)
                        
                        ForEach(store.projects) { project in
                            HStack {
                                Image(systemName: project.providerType.systemImageName)
                                Text(project.displayName)
                            }
                            .tag(project as Project?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Options")) {
                    Toggle("Start session immediately", isOn: $startImmediately)
                }
                
                if let project = selectedProject {
                    Section(header: Text("Project Info")) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Path:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(project.path.path)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                            
                            Spacer()
                        }
                        
                        HStack {
                            Text("Provider:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Label(project.providerType.displayName, systemImage: project.providerType.systemImageName)
                                    .font(.body)
                                
                                if let version = providerVersion {
                                    Text("v\(version)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Checking version...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        HStack {
                            Text("Existing Sessions:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(store.getSessionsForProject(project)?.count ?? 0)")
                                .font(.body)
                        }
                        
                        HStack {
                            Text("Active Sessions:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(store.getActiveSessionsForProject(project).count)")
                                .font(.body)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            // Auto-select the currently selected project
            selectedProject = store.selectedProject
            
            // Auto-generate session name
            if sessionName.isEmpty {
                sessionName = generateSessionName()
            }
            
            // Load provider version for selected project
            if let project = selectedProject {
                Task {
                    providerVersion = await store.getProviderVersion(for: project.providerType)
                }
            }
        }
        .onChange(of: selectedProject) { newProject in
            // Load provider version when project changes
            if let project = newProject {
                Task {
                    providerVersion = await store.getProviderVersion(for: project.providerType)
                }
            } else {
                providerVersion = nil
            }
        }
    }
    
    private var isFormValid: Bool {
        !sessionName.isEmpty && selectedProject != nil
    }
    
    private func generateSessionName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, HH:mm"
        return "Session \(formatter.string(from: Date()))"
    }
    
    private func createSession() {
        guard let project = selectedProject else { return }
        
        Task {
            await store.createSession(for: project, name: sessionName)
            
            if store.error == nil {
                // Start session immediately if requested
                if startImmediately, let newSession = store.selectedSession {
                    await store.startSession(newSession)
                }
                
                dismiss()
            }
        }
    }
}

#Preview {
    AddSessionView(store: CodeCaptainStore())
}