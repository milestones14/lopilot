import SwiftUI
import Markdown
import DeviceNameKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var currentPrompt: String = ""
    @State private var currentSessionID: UUID?
    @State private var isLoading: Bool = false
    @State private var currentProcess: Process? = nil
    @State private var streamingResponse: String = ""
    @State private var serverProcess: Process? = nil
    @StateObject private var chatHistory = ChatHistory()
    @State private var isAnimatingSuggestions: Bool = false
    @State private var attachedFiles: [AttachedFile] = []
    @State private var isImporting: Bool = false
    @State private var modelsToSizes = GlobalVariables.modelsToSizes
    @State private var visibleSuggestions: [PromptSuggestion] = []
    @State private var selectedModel: String = ""
    @State var selectedItem: String? = "chat"
    @StateObject private var sidebarVisibility = SidebarVisibility()
    @State private var isSigningOut: Bool = false
    @State private var popUpMenuShows: Bool = false
    @State private var installedModels: Set<String> = []
    @State private var isInstalling: [String: Bool] = [:]
    @State private var isUninstalling: [String: Bool] = [:]
    @State private var modelProgress: [String: ModelPullProgress] = [:]
    @State private var isTargeted: Bool = false
    @State private var editingSessionID: UUID? = nil
    @State private var editingText: String = ""

    let models = GlobalVariables.models
    let modelsUser = GlobalVariables.modelsUser
    let modelsToParams = GlobalVariables.modelsToParams
    private var promptSuggestions = GlobalVariables.promptSuggestions
    private var promptSuggestionsCode = GlobalVariables.promptSuggestionsCode

    // Computed property: a binding to the selected ChatSession in chatHistory
    var currentSession: Binding<ChatSession> {
        guard let id = currentSessionID,
              let index = chatHistory.sessions.firstIndex(where: { $0.id == id }) else {
            // Fallback: constant value if something is wrong
            return .constant(ChatSession(name: "Unknown"))
        }
        return $chatHistory.sessions[index]
    }

    var installedDisplayNames: [String] {
        var result: [String] = []
        for (displayName, internalName) in models {
            if let variants = modelsToParams[internalName] {
                for variant in variants {
                    let fullModelName = "\(internalName):\(variant)"
                    if installedModels.contains(fullModelName) {
                        result.append("\(displayName) (\(variant))")
                    }
                }
            }
        }
        return result.sorted()
    }

    var installedInternalNames: [String] {
        installedModels.sorted()
    }

    var body: some View {
        NavigationView {
            if sidebarVisibility.isSidebarVisible {
                List(selection: $selectedItem) {
                    NavigationLink(destination: chatView.navigationTitle(currentSession.wrappedValue.name).onAppear(perform: showSuggestions),
                                   tag: "chat", selection: $selectedItem) {
                        Label("Ask", systemImage: "bubble")
                    }
                    Divider()
                    NavigationLink(destination: chatsView.navigationTitle("Chat History"),
                                   tag: "chats", selection: $selectedItem) {
                        Label("Chat History", systemImage: "clock")
                    }
                    NavigationLink(destination: modelsView.navigationTitle("Models"),
                                   tag: "models", selection: $selectedItem) {
                        Label("Models", systemImage: "cube")
                    }
                }
                .listStyle(SidebarListStyle())
            }
            chatView.navigationTitle(currentSession.wrappedValue.name)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: createNewChat) {
                    Image(systemName: "plus")
                }
            }
        }
        .environmentObject(sidebarVisibility)
        .onAppear {
            fetchInstalledModels {
                if let lastModel = UserPreferences().getLastSelectedModel(),
                   installedInternalNames.contains(lastModel) {
                    selectedModel = lastModel
                } else if !installedInternalNames.isEmpty {
                    selectedModel = installedInternalNames[0]
                }
            }
            
            // Always open a fresh chat, but use last one of empty (to avoid creating endless chats)
            if currentSessionID == nil {
                if let first = chatHistory.sessions.first, first.messages.count == 1 { // 1 for system message
                    // Use empty chat
                    currentSessionID = first.id
                } else {
                    // Make new empty chat
                    createNewChat()
                }
            }
        }
    }

    // MARK: - Views

    var modelsView: some View {
        VStack(alignment: .leading) {
            Text("Installed & Available Models")
                .font(.largeTitle)
                .bold()
                .padding(.bottom)
            ScrollView {
                ForEach(models.sorted(by: { $0.key < $1.key }), id: \.key) { (displayName, internalName) in
                    Section(header: Text(displayName).font(.title2).bold().padding(.top)) {
                        ForEach(modelsToParams[internalName] ?? [], id: \.self) { variant in
                            let fullModelName = "\(internalName):\(variant)"
                            HStack {
                                Text(fullModelName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                if let progress = modelProgress[fullModelName], !progress.isFinished {
                                    if let latestDigest = progress.digests.keys.sorted().last,
                                       let pct = progress.digests[latestDigest] {
                                        ProgressView(value: pct)
                                            .progressViewStyle(LinearProgressViewStyle())
                                            .frame(width: .infinity, height: 6)
                                            .padding(.horizontal, 8)
                                    } else if let stage = progress.stageMessages.last {
                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                                .scaleEffect(0.5)
                                            Text(stage)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 8)
                                    }
                                }
                                Spacer()
                                Text(modelsToSizes[fullModelName] ?? "Unknown")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                if installedModels.contains(fullModelName) {
                                    Button(action: {
                                        uninstallModel(modelName: fullModelName)
                                    }) {
                                        Text("Uninstall")
                                            .foregroundColor(.red)
                                    }
                                } else if isInstalling[fullModelName] ?? false {
                                    Button("Installing...") { }
                                        .disabled(true)
                                } else {
                                    Button("Install") {
                                        installModel(modelName: fullModelName)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding()
        }
        .padding()
        .onAppear {
            fetchInstalledModels(afterFetched: nil)
        }
    }

    var chatsView: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Chat History")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom)
                
                Spacer()
                
                Button(action: {
                    var value = 0
                    if chatHistory.sessions.count > 100 {
                        value = (chatHistory.sessions.count / 10) * 10
                    } else {
                        value = chatHistory.sessions.count
                    }
                    
                    let alert = NSAlert()
                    alert.messageText = "Clear All Chats?"
                    alert.informativeText = "This will permanently delete your entire chat history (\(value == chatHistory.sessions.count ? "\(chatHistory.sessions.count) chat\(value == 1 ? "" : "s")" : "\(value)+ chat\(value == 1 ? "" : "s")")). This action cannot be undone."
                    alert.alertStyle = .warning
                    
                    // The first button added becomes the default (Return key)
                    alert.addButton(withTitle: "Clear All")
                    // The second button becomes the cancel button (Escape key)
                    alert.addButton(withTitle: "Cancel")
                    
                    // Set the first button to a destructive appearance (macOS 11+)
                    if #available(macOS 11.0, *) {
                        alert.buttons[0].hasDestructiveAction = true
                    }

                    // Show the alert as a sheet attached to the window
                    if let window = NSApp.keyWindow {
                        alert.beginSheetModal(for: window) { response in
                            if response == .alertFirstButtonReturn {
                                // The user clicked "Clear All"
                                self.deleteAllChats()
                            }
                        }
                    } else {
                        // Fallback if no window is active
                        if alert.runModal() == .alertFirstButtonReturn {
                            self.deleteAllChats()
                        }
                    }
                }) {
                    Text("Clear All")
                        .foregroundColor(.red)
                }
            }
            List {
                ForEach(chatHistory.sessions) { session in
                    HStack {
                        VStack(alignment: .leading) {
                            if editingSessionID == session.id {
                                // The Editable TextField
                                TextField("Session Name", text: $editingText, onCommit: {
                                    saveNewName(for: session)
                                })
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit { saveNewName(for: session) }
                            } else {
                                // The Standard View
                                Text(session.name)
                                    .font(.headline)
                                Text(session.timestamp, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()

                        // Edit Button Logic
                        Button(action: {
                            if editingSessionID == session.id {
                                saveNewName(for: session)
                            } else {
                                editingText = session.name
                                editingSessionID = session.id
                            }
                        }) {
                            Image(systemName: editingSessionID == session.id ? "checkmark.circle" : "square.and.pencil")
                                .foregroundColor(editingSessionID == session.id ? .green : .primary)
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: {
                            let alert = NSAlert()
                            alert.messageText = "Delete '\(session.name)'?"
                            alert.informativeText = "This action cannot be undone."
                            alert.alertStyle = .warning
                            
                            // The first button added becomes the default (Return key)
                            alert.addButton(withTitle: "Delete")
                            // The second button becomes the cancel button (Escape key)
                            alert.addButton(withTitle: "Cancel")
                            
                            // Set the first button to a destructive appearance (macOS 11+)
                            if #available(macOS 11.0, *) {
                                alert.buttons[0].hasDestructiveAction = true
                            }

                            // Show the alert as a sheet attached to the window
                            if let window = NSApp.keyWindow {
                                alert.beginSheetModal(for: window) { response in
                                    if response == .alertFirstButtonReturn {
                                        if session.id != currentSessionID {
                                            chatHistory.deleteSession(session.id)
                                        } else {
                                            currentSessionID = nil
                                            chatHistory.deleteSession(session.id)
                                            createNewChat()
                                        }
                                    }
                                }
                            } else {
                                // Fallback if no window is active
                                if alert.runModal() == .alertFirstButtonReturn {
                                    if session.id != currentSessionID {
                                        chatHistory.deleteSession(session.id)
                                    } else {
                                        currentSessionID = nil
                                        chatHistory.deleteSession(session.id)
                                        createNewChat()
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Only switch chats if we aren't currently editing a title
                        if editingSessionID == nil {
                            currentSessionID = session.id
                            selectedItem = "chat"
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding()
    }
    private func saveNewName(for session: ChatSession) {
        guard !editingText.trimmingCharacters(in: .whitespaces).isEmpty else {
            editingSessionID = nil
            return
        }
        
        if let index = chatHistory.sessions.firstIndex(where: { $0.id == session.id }) {
            chatHistory.sessions[index].name = editingText
            chatHistory.saveSession(chatHistory.sessions[index])
        }
        
        editingSessionID = nil
        editingText = ""
    }
    // MARK: - Main Chat View
    var chatView: some View {
        VStack(alignment: .leading) {
            chatHeader
            
            messageListSection
            
            Spacer()
            
            inputAreaSection
        }
        .padding()
        .onAppear {
            if visibleSuggestions.isEmpty {
                showSuggestions()
            }
            
            startServerAndPullModel()
            if let id = currentSessionID,
               !chatHistory.sessions.contains(where: { $0.id == id }) {
                chatHistory.saveSession(currentSession.wrappedValue)
            }
        }
        .overlay {
            if isTargeted {
                ZStack {
                    Color.accentColor.opacity(0.1)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                        Text("Drop files to attach")
                            .font(.headline)
                    }
                }
                .padding() // Match your chatView padding
                .transition(.opacity)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            print("[DROP LOG] Drop initiated with \(providers.count) providers")
            
            let currentCount = attachedFiles.count
            let remainingSlots = 10 - currentCount
            if remainingSlots <= 0 {
                print("[DROP LOG] Cancelled: No remaining slots (Max 10)")
                return false
            }

            for (index, provider) in providers.prefix(remainingSlots).enumerated() {
                print("[DROP LOG] Processing provider #\(index + 1)")
                
                // Using loadObject(ofClass: URL.self) is more modern and reliable for file paths
                provider.loadObject(ofClass: URL.self) { url, error in
                    if let error = error {
                        print("[DROP LOG] Provider error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let url = url else {
                        print("[DROP LOG] Failed to extract URL from provider")
                        return
                    }
                    
                    print("[DROP LOG] File detected: \(url.lastPathComponent)")

                    // 1. Security Access
                    let canAccess = url.startAccessingSecurityScopedResource()
                    print("[DROP LOG] Security access granted: \(canAccess)")
                    
                    defer {
                        if canAccess { url.stopAccessingSecurityScopedResource() }
                    }

                    // 2. Identify Content Type
                    do {
                        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
                        let contentType = resourceValues.contentType
                        print("[DROP LOG] Content Type identified as: \(contentType?.identifier ?? "unknown")")
                        
                        // 3. Attempt to Read
                        // We try to read anything. If it's binary, String(contentsOf:) will throw an error
                        if let content = try? String(contentsOf: url, encoding: .utf8) {
                            print("[DROP LOG] Successfully read string content (\(content.count) chars)")
                            DispatchQueue.main.async {
                                let newFile = AttachedFile(name: url.lastPathComponent, content: content)
                                self.attachedFiles.append(newFile)
                                print("[DROP LOG] File appended to UI state")
                            }
                        } else {
                            print("[DROP LOG] FAILED: File exists but could not be read as a UTF-8 string (likely binary or wrong encoding)")
                        }
                        
                    } catch {
                        print("[DROP LOG] ERROR reading resource values: \(error.localizedDescription)")
                    }
                }
            }
            return true
        }
        .onDisappear {
            serverProcess?.terminate()
        }
        .onChange(of: currentSession.wrappedValue) { newSession in
            chatHistory.saveSession(newSession)
        }
    }
    
    private func showSuggestions() {
        isAnimatingSuggestions = false

        let codingSuggestions = Array(
            promptSuggestionsCode
                .shuffled()
                .prefix(3)
                .sortedByVisualWidth(\.content, order: .smallToLarge)
        )

        if selectedModel.lowercased().contains("code") {
            // Specific to coding models (e.g. Meta **Code** Llama)
            visibleSuggestions = codingSuggestions
        } else {
            // Otherwise, show generic suggestions
            visibleSuggestions = (promptSuggestions + promptSuggestionsCode)
                .shuffled()
                .prefix(3)
                .sortedByVisualWidth(\.content, order: .smallToLarge)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.interpolatingSpring(stiffness: 120, damping: 14)) {
                isAnimatingSuggestions = true
            }
        }
    }

    // MARK: - Sub-Views

    private var chatHeader: some View {
        HStack {
            Text("Chat")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 5)
            Spacer()
            modelPicker
        }
    }

    private var modelPicker: some View {
        Picker("", selection: $selectedModel) {
            if installedInternalNames.isEmpty {
                Text("Loading...").tag("")
            } else {
                ForEach(installedInternalNames, id: \.self) { internalName in
                    Text(GlobalFunctions.displayName(for: internalName)).tag(internalName)
                }
            }
        }
        .frame(maxWidth: 250)
        .disabled(installedInternalNames.isEmpty)
        .onChange(of: selectedModel) { newValue in
            if !newValue.isEmpty {
                UserPreferences().saveLastSelectedModel(newValue)
                showSuggestions()
            }
        }
    }
    
    @ViewBuilder
    private var messageListSection: some View {
        if currentSession.wrappedValue.messages.count > 1 {
            chatScrollView
        } else {
            emptyStateView
        }
    }

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(currentSession.wrappedValue.messages) { message in
                        ChatBubble(message: message).id(message.id)
                    }
                    
                    if isLoading || !streamingResponse.isEmpty {
                        ChatBubble(message: Message(
                            role: .assistant,
                            text: streamingResponse,
                            modelUserFriendly: GlobalFunctions.displayName(for: selectedModel),
                            isLoading: streamingResponse.isEmpty // Set to true only if text is empty
                        ))
                        .id("streaming")
                    }
                }
                .padding()
            }
            .onChange(of: currentSession.wrappedValue.messages) { _ in
                DispatchQueue.main.async {
                    withAnimation { proxy.scrollTo(currentSession.wrappedValue.messages.last?.id, anchor: .bottom) }
                }
            }
            .onChange(of: streamingResponse) { _ in
                DispatchQueue.main.async {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            Text("How can I help you today?")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            VStack(spacing: 12) {
                ForEach(Array(visibleSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                    Text(suggestion.content)
                        .padding()
                        .background(.gray.opacity(0.1))
                        .cornerRadius(10)
                        .offset(y: isAnimatingSuggestions ? 0 : CGFloat(50 + (index * 60)))
                        .opacity(isAnimatingSuggestions ? 1 : 0)
                        .hoverScale()
                        .onTapGesture {
                            if !isLoading {
                                currentPrompt = suggestion.content
                                sendPrompt()
                            }
                        }
                }
            }
            .padding(.top, 20)
            
            Button(action: {
                showSuggestions()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    
                    Text("Retry")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
                .padding(2)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.interpolatingSpring(stiffness: 100, damping: 15), value: isAnimatingSuggestions)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))
    }

    private var inputAreaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Attachment Preview Chips
            if !attachedFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachedFiles) { file in
                            HStack(spacing: 4) {
                                Text(file.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Button(action: { attachedFiles.removeAll(where: { $0.id == file.id }) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 45)
                }
                .frame(height: 30)
            }

            HStack(alignment: .bottom) {
                // File Attachment Button
                Button(action: { isImporting = true }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .padding(5)
                        .contentShape(Rectangle())
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    Color(red: 218/255, green: 218/255, blue: 218/255),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(attachedFiles.count >= 10)
                .help("Attach text files (Max 10)")

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $currentPrompt)
                        .font(.system(.body))
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 35, maxHeight: 180)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(6)
                        .scrollContentBackground(.hidden)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPrompt.contains("\n"))
                        .onKeyPress(.return) {
                            let isShiftPressed = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
                            if !isLoading && !currentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isShiftPressed {
                                sendPrompt()
                            } else if isShiftPressed {
                                currentPrompt += "\n"
                            }
                            return .handled
                        }
                    
                    if currentPrompt.isEmpty {
                        Text("Ask anything...")
                            .foregroundColor(.gray.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.leading, 8)
                            .padding(.top, 6)
                            .allowsHitTesting(false)
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                
                Button(action: {
                    isLoading ? stopStreaming() : sendPrompt()
                }) {
                    Text(isLoading ? "Stop" : "Send")
                    .padding(5)
                }
                .padding(.horizontal, 8)
                .cornerRadius(6.5)
                .disabled(currentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedModel.isEmpty)
            }
        }
        .padding(.top)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.text, .plainText, .sourceCode, .swiftSource],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    if attachedFiles.count >= 10 { break }
                    // macOS requirement: Start accessing the security-scoped resource
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let content = try? String(contentsOf: url, encoding: .utf8) {
                            let newFile = AttachedFile(name: url.lastPathComponent, content: content)
                            attachedFiles.append(newFile)
                        }
                    }
                }
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helper / Commands
    private func selectFiles() {
        isImporting = true
    }
    
    private func deleteAllChats() {
        stopStreaming()
        currentSessionID = nil
        chatHistory.clearAllSessions()
        createNewChat()
    }

    private func processSelectedFiles(_ results: [URL]) {
        for url in results {
            if attachedFiles.count >= 10 { break }
            
            // macOS security requirement for reading external files
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let newFile = AttachedFile(name: url.lastPathComponent, content: content)
                attachedFiles.append(newFile)
            } catch {
                print("Failed to read file: \(error)")
            }
        }
    }

    private func formatPromptWithAttachments(_ message: String) -> String {
        if attachedFiles.isEmpty { return message }
        
        var formatted = message + "\n\n--- USER ATTACHED FILES ---\n"
        for file in attachedFiles {
            formatted += "\(file.name):\n\n```\n\(file.content)\n```\n\n"
        }
        return formatted
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    
    private func createNewChat() {
        let newSession = ChatSession(
            name: "New Chat \(chatHistory.sessions.count + 1)",
            messages: [
                Message(role: .system, text: "SYSTEM INSTRUCTIONS: You are a friendly, helpful assistant that doesn't use any emojis if the conversation is regarding code.", modelUserFriendly: "NONE", isLoading: false)
            ]
        )
        chatHistory.saveSession(newSession)
        currentSessionID = newSession.id // Update the session ID to select the new session
        selectedItem = "chat"
    }


    private func checkAvailability() -> Bool {
        var isAvailable = true
        if !GlobalFunctions.isOllamaAvailable() {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Ollama not installed"
                alert.informativeText = "Ollama is not installed, and Lopilot cannot work without it. Please install Ollama from `ollama.com`."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            isAvailable = false
        }
        if installedInternalNames.isEmpty {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "No models installed"
                alert.informativeText = "No models are installed. Please install a model of your choice in the Models tab."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            isAvailable = false
        }
        return isAvailable
    }

    func fetchInstalledModels(afterFetched: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            let listCommand = "/usr/local/bin/ollama list"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", listCommand]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let modelLines = output.split(separator: "\n").dropFirst()
                let models = modelLines.compactMap { line -> String? in
                    let parts = line.split(separator: " ", maxSplits: 1)
                    return parts.first.map(String.init)?.trimmingCharacters(in: .whitespaces)
                }
                DispatchQueue.main.async {
                    self.installedModels = Set(models)
                    afterFetched?()
                }
            } catch {
                print("Error fetching installed models: \(error)")
                DispatchQueue.main.async {
                    self.installedModels = []
                    afterFetched?()
                }
            }
        }
    }

    func parseProgressOutput(modelName: String, output: String) {
        var progress = modelProgress[modelName] ?? ModelPullProgress()
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.isEmpty { continue }
            if line.starts(with: "pulling ") {
                if let range = line.range(of: #"pulling ([a-f0-9]+): +(\d+)%"#, options: .regularExpression) {
                    let matchStr = String(line[range])
                    let parts = matchStr.components(separatedBy: ":")
                    if parts.count >= 2,
                       let percentStr = parts[1].components(separatedBy: "%").first?
                         .trimmingCharacters(in: .whitespaces),
                       let percent = Float(percentStr) {
                        let digest = parts[0]
                            .replacingOccurrences(of: "pulling ", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        progress.digests[digest] = percent / 100.0
                    }
                } else if !progress.stageMessages.contains(line) {
                    progress.stageMessages.append(line)
                }
            } else if !progress.stageMessages.contains(line) {
                progress.stageMessages.append(line)
            }
        }
        modelProgress[modelName] = progress
    }

    func installModel(modelName: String) {
        isInstalling[modelName] = true
        modelProgress[modelName] = ModelPullProgress()
        DispatchQueue.global(qos: .userInitiated).async {
            let pullCommand = "/usr/local/bin/ollama pull \(modelName)"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", pullCommand]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            let fileHandle = pipe.fileHandleForReading
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async {
                    self.parseProgressOutput(modelName: modelName, output: output)
                }
            }
            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    isInstalling[modelName] = false
                    modelProgress[modelName]?.isFinished = true
                    fetchInstalledModels(afterFetched: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    isInstalling[modelName] = false
                    modelProgress[modelName]?.stageMessages.append("Failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func uninstallModel(modelName: String) {
        isUninstalling[modelName] = true
        DispatchQueue.global(qos: .userInitiated).async {
            let pullCommand = "/usr/local/bin/ollama rm \(modelName)"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", pullCommand]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    isUninstalling[modelName] = false
                    fetchInstalledModels(afterFetched: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    isUninstalling[modelName] = false
                    print("Error uninstalling model \(modelName): \(error)")
                }
            }
        }
    }

    func startServerAndPullModel() {
        if serverProcess?.isRunning ?? false {
            return
        }
        let checkCommand = "curl -s http://localhost:11434"
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        checkProcess.arguments = ["-c", checkCommand]
        let checkPipe = Pipe()
        checkProcess.standardOutput = checkPipe
        checkProcess.standardError = checkPipe
        do {
            try checkProcess.run()
            checkProcess.waitUntilExit()
            if checkProcess.terminationStatus != 0 {
                let newServerProcess = Process()
                newServerProcess.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
                newServerProcess.arguments = ["serve"]
                let serverPipe = Pipe()
                newServerProcess.standardOutput = serverPipe
                newServerProcess.standardError = serverPipe
                try newServerProcess.run()
                self.serverProcess = newServerProcess
            }
        } catch {
            DispatchQueue.main.async {
                streamingResponse = "Error starting server: \(error.localizedDescription)"
            }
        }
    }
    
    func getResponse(prompt: String) async -> String? {
        if !checkAvailability() {
            return nil
        }
        
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let payload: [String: Any] = [
            "model": selectedModel.isEmpty ? "gemma3:1b" : selectedModel,
            "prompt": trimmed,
            "stream": false
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            print("Failed to create payload.")
            return nil
        }
        
        let url = URL(string: "http://localhost:11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let output = String(data: data, encoding: .utf8),
                  let jsonData = output.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any],
                  let aiResponse = json["response"] as? String else {
                print("Failed to parse response.")
                return nil
            }
            return aiResponse
        } catch {
            print("Error executing request: \(error)")
            return nil
        }
    }
    
    private func generateTitle(for sessionID: UUID, basedOn prompt: String) {
        Task {
            // A specific hidden prompt to force a concise summary
            let titlePrompt = "Summarize this request into a title of 3-5 words. Do not use quotes, punctuation, or Markdown: \"\(prompt)\""
            let model = selectedModel.isEmpty ? "gemma3:1b" : selectedModel
            
            guard let url = URL(string: "http://localhost:11434/api/generate") else { return }
            
            let body: [String: Any] = [
                "model": model,
                "prompt": titlePrompt,
                "stream": false
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let title = json["response"] as? String {
                    
                    await MainActor.run {
                        if let index = chatHistory.sessions.firstIndex(where: { $0.id == sessionID }) {
                            // Clean up quotes and newlines generated by the model
                            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                                  .replacingOccurrences(of: "\"", with: "")
                            chatHistory.sessions[index].name = cleanTitle
                            chatHistory.objectWillChange.send() // Refresh sidebar UI
                        }
                    }
                }
            } catch {
                print("Title generation failed: \(error)")
            }
        }
    }
    
    func sendPrompt() {
        Task { @MainActor in
            if !checkAvailability() { return }
            let fetcher = DeviceNameFetcher(cachePolicy: .threeDays)
            fetcher.preload()
            let rawPrompt = currentPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawPrompt.isEmpty && !isLoading else { return }

            // 1. Capture current attachments for the UI and History
            let messageAttachments = attachedFiles.isEmpty ? nil : attachedFiles
            
            // 2. Format the prompt for the AI payload (the long version with file contents)
            let aiFormattedPrompt = formatPromptWithAttachments(rawPrompt)

            // 3. UI Prep: Add the user message with its attachments
            let userMsg = Message(
                role: .user,
                text: rawPrompt,
                modelUserFriendly: "NONE",
                isLoading: false,
                attachments: messageAttachments
            )
            currentSession.wrappedValue.messages.append(userMsg)
            chatHistory.saveSession(currentSession.wrappedValue)
            
            if currentSession.wrappedValue.messages.filter({ $0.role == .user }).count == 1 {
                if let sessionID = currentSessionID {
                    generateTitle(for: sessionID, basedOn: rawPrompt)
                }
            }
            
            // 1. Get the list of all apps for general context
            let userApps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && $0.localizedName != "Lopilot" && $0.localizedName != "Finder"
            }

            let usrAppsString = userApps
                .compactMap { $0.localizedName }
                .joined(separator: ", ")

            // 2. Use our "Memory" for the specific focus
            let lastActiveApp = AppTracker.shared.lastActiveApp

            // 3. Build context
            let fullContext = currentSession.wrappedValue.messages.dropLast().map { msg in
                let extras = """
                --- SYSTEM CONTEXT ---
                Current Time: \(Date().formatted(date: .complete, time: .complete))
                Time Zone: \(TimeZone.current.identifier)
                User Identity: \(NSFullUserName()) (Always address the user by name, and fill any placeholders in generated text with this, including braces()[])

                ENVIRONMENT:
                OS: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
                Hardware: \(fetcher.deviceModel ?? "Mac")
                Most Recent Active App: \(lastActiveApp)
                All Running Apps: \(usrAppsString)

                INSTRUCTIONS:
                1. Use "Most Recent Active App" (\(lastActiveApp)) as the primary context. 
                2. If the user mentions "this app", "this window", or "here", they are referring to \(lastActiveApp).
                3. If \(lastActiveApp) is "Unknown", rely on the "All Running Apps" list for relevance.
                4. Tailor technical advice to macOS \(ProcessInfo.processInfo.operatingSystemVersionString).
                5. It's great to greet \(NSFullUserName()) at the very start of the conversation, but you shouldn't keep greeting \(NSFullUserName()) in subsequent messages.
                """
                
                print(extras)
                
                if let attachments = msg.attachments, !attachments.isEmpty {
                    // Reconstruct the formatted prompt for history messages, and other useful details
                    var formatted = msg.text + "\n\n--- USER ATTACHED FILES ---"
                    for file in attachments {
                        formatted += "\n\(file.name):\n\n```\n\(file.content)\n```\n"
                    }
                    return formatted + extras
                }
                return msg.text + extras
            }.joined(separator: "\n") + (currentSession.wrappedValue.messages.count > 1 ? "\n" : "") + aiFormattedPrompt
            
            let model = selectedModel.isEmpty ? "gemma3:1b" : selectedModel
            
            // Reset Inputs
            currentPrompt = ""
            attachedFiles = []
            streamingResponse = ""
            isLoading = true

            Task.detached(priority: .userInitiated) {
                guard let payload = await GlobalFunctions.makePayload(with: fullContext, model: model) else { return }
                
                var request = URLRequest(url: URL(string: "http://localhost:11434/api/generate")!)
                request.httpMethod = "POST"
                request.httpBody = payload.data(using: .utf8)

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }

                    var accumulated = ""
                    var lastUpdate = Date()

                    for try await line in bytes.lines {
                        let part = await GlobalFunctions.parsePlainText(line)
                        accumulated += part
                        
                        if Date().timeIntervalSince(lastUpdate) > 0.05 {
                            let textToDisplay = accumulated
                            await MainActor.run { self.streamingResponse = textToDisplay }
                            lastUpdate = Date()
                        }
                    }
                    await MainActor.run { finalizeLoading(with: accumulated, model: model) }
                } catch {
                    await MainActor.run { finalizeLoading(with: "Error: \(error.localizedDescription)", model: model) }
                }
            }
        }
    }

    @MainActor private func finalizeLoading(with finalResult: String, model: String) {
        isLoading = false
        
        if !finalResult.isEmpty {
            // Resolve the friendly name before creating the message
            let friendlyName = GlobalFunctions.displayName(for: model)
            let assistantMsg = Message(role: .assistant, text: finalResult, modelUserFriendly: friendlyName, isLoading: false)
            currentSession.wrappedValue.messages.append(assistantMsg)
        }
        
        streamingResponse = ""
        chatHistory.saveSession(currentSession.wrappedValue)
    }

    // Helper to ensure state is always reset
    @MainActor private func finalizeLoading() {
        self.isLoading = false
        self.streamingResponse = ""
        self.chatHistory.saveSession(self.currentSession.wrappedValue)
    }
    
    func stopStreaming() {
        currentProcess?.terminate()
        isLoading = false
        currentProcess = nil
        if !streamingResponse.isEmpty {
            // Use the friendly name here as well
            let friendlyName = GlobalFunctions.displayName(for: selectedModel)
            let assistantMsg = Message(role: .assistant, text: streamingResponse, modelUserFriendly: friendlyName, isLoading: false)
            currentSession.wrappedValue.messages.append(assistantMsg)
            chatHistory.saveSession(currentSession.wrappedValue)
            streamingResponse = ""
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
