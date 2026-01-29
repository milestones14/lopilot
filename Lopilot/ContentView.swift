import SwiftUI
import Markdown

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

    let models: [String: String] = [
        "Google Gemma3": "gemma3",
        "Meta Llama 3.1": "llama3.1",
        "Mistral": "mistral",
        "DeepSeek R1": "deepseek-r1",
        "Meta Code Llama": "codellama"
    ]
    
    let modelsUser: [String: String] = [
        "gemma3": "Google Gemma3",
        "llama3.1": "Meta Llama 3.1",
        "mistral": "Mistral",
        "deepseek-r1": "DeepSeek R1",
        "codellama": "Meta Code Llama"
    ]

    let modelsToParams: [String: [String]] = [
        "gemma3": ["1b", "4b", "12b", "27b"],
        "llama3.1": ["8b", "70b", "405b"],
        "mistral": ["7b"],
        "deepseek-r1": ["1.5b", "7b", "8b", "14b", "32b", "70b", "671b"],
        "codellama": ["7b", "13b", "34b", "70b"]
    ]
    
    // --- General, Creative & Lifestyle (30 items) ---
    private var promptSuggestions: [promptSuggestion] {
        [
            promptSuggestion(content: "Suggest 5 healthy breakfast ideas with eggs"),
            promptSuggestion(content: "How do I make a sourdough starter from scratch?"),
            promptSuggestion(content: "Summarize the plot of the Great Gatsby in three sentences"),
            promptSuggestion(content: "Explain the theory of relativity using a sports analogy"),
            promptSuggestion(content: "Give me a 15-minute bodyweight workout routine"),
            promptSuggestion(content: "How does a blockchain actually work?"),
            promptSuggestion(content: "Write a formal cover letter for a Software Engineer role"),
            promptSuggestion(content: "Translate 'Where is the nearest train station?' into Japanese"),
            promptSuggestion(content: "Create a list of 10 travel essentials for a hiking trip"),
            promptSuggestion(content: "Write a funny script for a 30-second coffee commercial"),
            promptSuggestion(content: "What are the pros and cons of remote work?"),
            promptSuggestion(content: "Explain how photosynthesis works to a middle schooler"),
            promptSuggestion(content: "How can I improve my focus while working from home?"),
            promptSuggestion(content: "What is the best way to learn a new language quickly?"),
            promptSuggestion(content: "Describe the architectural style of the Renaissance"),
            promptSuggestion(content: "Suggest 5 classic sci-fi books for a beginner"),
            promptSuggestion(content: "What are the main causes of the French Revolution?"),
            promptSuggestion(content: "How do electric vehicle batteries differ from phone batteries?"),
            promptSuggestion(content: "What are some effective networking tips for introverts?"),
            promptSuggestion(content: "Write a short ghost story set in a library"),
            promptSuggestion(content: "How does the stock market work for beginners?"),
            promptSuggestion(content: "Explain the difference between a latte and a cappuccino"),
            promptSuggestion(content: "Provide a recipe for a classic Margherita pizza"),
            promptSuggestion(content: "Write a polite rejection letter for a job applicant"),
            promptSuggestion(content: "What are the environmental benefits of vertical farming?"),
            promptSuggestion(content: "Draft a beginner-friendly 10-step guide to meditation"),
            promptSuggestion(content: "Write a thank-you note to a mentor who helped with a career move"),
            promptSuggestion(content: "What are 5 essential tips for first-time home buyers?"),
            promptSuggestion(content: "How do noise-canceling headphones work physically?"),
            promptSuggestion(content: "Explain the concept of 'opportunity cost' with an everyday example"),
            promptSuggestion(content: "What is the history behind the Olympic Games?"),
            promptSuggestion(content: "Create a step-by-step checklist for launching a startup"),
            promptSuggestion(content: "Explain how the immune system remembers viruses"),
            promptSuggestion(content: "What are the best plants for a low-light apartment?")
        ]
    }
    
    // --- Coding & Tech (17 items) ---
    private var promptSuggestionsCode: [promptSuggestion] {
        [
            promptSuggestion(content: "Write a Hello World application in React"),
            promptSuggestion(content: "What are the primary differences between Swift and Kotlin?"),
            promptSuggestion(content: "Write a Python script to scrape news headlines"),
            promptSuggestion(content: "What are the best practices for accessibility in web design?"),
            promptSuggestion(content: "Explain the difference between SQL and NoSQL databases"),
            promptSuggestion(content: "Write a CSS snippet for a glassmorphism card effect"),
            promptSuggestion(content: "How do I center a div using Flexbox?"),
            promptSuggestion(content: "Write a bash script to automate folder backups"),
            promptSuggestion(content: "Explain the concept of 'technical debt' to a non-coder"),
            promptSuggestion(content: "What are the most common design patterns in Swift?"),
            promptSuggestion(content: "How do I fix a 'merge conflict' in Git?"),
            promptSuggestion(content: "Explain the difference between deep learning and machine learning"),
            promptSuggestion(content: "How do I optimize a website for Core Web Vitals?"),
            promptSuggestion(content: "How do I implement 'Dark Mode' in a SwiftUI app?"),
            promptSuggestion(content: "What are the best practices for securing a REST API?"),
            promptSuggestion(content: "Explain how an API works using a restaurant analogy"),
            promptSuggestion(content: "What is the difference between a compiler and an interpreter?"),
        ]
    }
    
    @State private var visibleSuggestions: [promptSuggestion] = []

    @State private var selectedModel: String = ""
    @State var selectedItem: String? = "chat"
    @StateObject private var sidebarVisibility = SidebarVisibility()
    @State private var isSigningOut: Bool = false
    @State private var popUpMenuShows: Bool = false

    @State private var installedModels: Set<String> = []
    @State private var isInstalling: [String: Bool] = [:]
    @State private var isUninstalling: [String: Bool] = [:]
    @State private var modelProgress: [String: ModelPullProgress] = [:]

    struct ModelPullProgress {
        var stageMessages: [String] = []
        var digests: [String: Float] = [:]
        var isFinished: Bool = false
    }

    @State private var modelsToSizes: [String: String] = [
        "deepseek-r1:1.5b": "1.1GB",
        "deepseek-r1:7b": "4.7GB",
        "deepseek-r1:8b": "5.2GB",
        "deepseek-r1:14b": "9GB",
        "deepseek-r1:32b": "20GB",
        "deepseek-r1:70b": "43GB",
        "deepseek-r1:671b": "404GB",
        "gemma3:1b": "815MB",
        "gemma3:4b": "3.3GB",
        "gemma3:12b": "8.1GB",
        "gemma3:27b": "17GB",
        "codellama:7b": "3.8GB",
        "codellama:13b": "7.4GB",
        "codellama:34b": "19GB",
        "codellama:70b": "39GB",
        "llama3.1:8b": "4.9GB",
        "llama3.1:70b": "43GB",
        "llama3.1:405b": "243GB",
        "mistral:7b": "4.4GB"
    ]

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
                            Text(session.name)
                                .font(.headline)
                            Text(session.timestamp, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: {
                            if session.id != currentSessionID {
                                chatHistory.deleteSession(session.id)
                            } else {
//                                let alert = NSAlert()
//                                alert.messageText = "Cannot Delete Current Chat"
//                                alert.informativeText = "Please switch to another chat or create a new one before deleting this chat."
//                                alert.alertStyle = .warning
//                                alert.addButton(withTitle: "OK")
//                                alert.runModal()

                                currentSessionID = nil
                                chatHistory.deleteSession(session.id)
                                createNewChat()
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        currentSessionID = session.id
                        selectedItem = "chat"
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding()
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
            let evenShowCode = Int.random(in: 1...100) <= 70
            
            let codingSelection = promptSuggestionsCode.shuffled().prefix(1)
            let genericSelection = promptSuggestions.shuffled().prefix(evenShowCode ? 2 : 3)
            
            if evenShowCode {
                visibleSuggestions = (genericSelection + codingSelection)
                    .shuffled()
                    .sortedByVisualWidth(\.content, order: .smallToLarge)
            } else {
                visibleSuggestions = (genericSelection)
                    .shuffled()
                    .sortedByVisualWidth(\.content, order: .smallToLarge)
            }
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
                    Text(displayName(for: internalName)).tag(internalName)
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
                            modelUserFriendly: displayName(for: selectedModel),
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

    // Helper to clean up the Picker logic
    private func displayName(for internalName: String) -> String {
        let components = internalName.split(separator: ":").map(String.init)
        let baseName = components.first ?? internalName
        let variant = components.last ?? ""
        
        // Look up the friendly name in modelsUser; fallback to the baseName if not found
        let friendlyBase = modelsUser[baseName] ?? baseName
        
        // Returns "Google Gemma3 (1b)" instead of "gemma3:1b"
        return variant.isEmpty ? friendlyBase : "\(friendlyBase) (\(variant))"
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
        if !isOllamaAvailable() {
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

    func isOllamaAvailable() -> Bool {
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
            return !output.lowercased().contains("command not found")
        } catch {
            print("Error checking Ollama: \(error)")
            return false
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

            // 4. Build context
            let fullContext = currentSession.wrappedValue.messages.dropLast().map { msg in
                let extras =
                    """
                    
                    
                    ---   SYSTEM DETAILS    ---
                    Date: \(Date().formatted(date: .complete,time: .complete))
                    """
                
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
                guard let payload = await self.makePayload(with: fullContext, model: model) else { return }
                // ... (rest of the streaming logic remains the same)
                var request = URLRequest(url: URL(string: "http://localhost:11434/api/generate")!)
                request.httpMethod = "POST"
                request.httpBody = payload.data(using: .utf8)

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }

                    var accumulated = ""
                    var lastUpdate = Date()

                    for try await line in bytes.lines {
                        let part = await self.parsePlainText(line)
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
            let friendlyName = displayName(for: model)
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
            let friendlyName = displayName(for: selectedModel)
            let assistantMsg = Message(role: .assistant, text: streamingResponse, modelUserFriendly: friendlyName, isLoading: false)
            currentSession.wrappedValue.messages.append(assistantMsg)
            chatHistory.saveSession(currentSession.wrappedValue)
            streamingResponse = ""
        }
    }

    func makePayload(with prompt: String, model: String) -> String? {
        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true
        ]
        // JSONSerialization handles all escaping (quotes, newlines, etc.) correctly
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonStr
    }

    func parsePlainText(_ jsonStr: String) -> String {
        let lines = jsonStr.components(separatedBy: .newlines)
        var result = ""
        for line in lines {
            guard let data = line.data(using: .utf8) else { continue }
            if let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
               let aiResponse = json["response"] as? String {
                result += aiResponse
            }
        }
        return result
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct ChatBubble: View {
    let message: Message
    var body: some View {
        if message.role != .system {
            VStack(alignment: message.role == .user ? .trailing : .leading) { // Align based on role
                if message.role == .assistant {
                    HStack {
                        Text((message.role == .assistant ? message.modelUserFriendly.components(separatedBy: " (").first?.trimmingCharacters(in: .whitespaces) : "") ?? message.modelUserFriendly)
                            .padding(5)
                            .font(.title2)
                        Spacer()
                    }
                }
                
                HStack {
                    if message.role == .user { Spacer() }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if message.role == .assistant && message.isLoading && message.text.isEmpty {
                            ProgressView()
                                .scaleEffect(0.6)
                                .padding(10)
                        } else {
                            MarkdownText(text: message.text)
                                .padding(10)
                        }

                        // Render Attachments specifically for this message
                        if let attachments = message.attachments, !attachments.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Attachments:")
                                    .font(.caption2.bold())
                                    .foregroundColor(.secondary)
                                
                                ForEach(attachments) { file in
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.text")
                                            .font(.caption2)
                                        Text(file.name)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                            .padding([.horizontal, .bottom], 8)
                        }
                    }
                    .background(message.role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    if message.role == .assistant { Spacer() }
                }
                
                if message.role == .assistant {
                    HStack {
                        Text("_AI Responses may contain mistakes. Check important info._")
                            .padding(5)
                            .font(.system(size: 10))
                        Spacer()
                    }
                }
            }
            .padding()
        }
    }
}

struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let segments = parseMarkdownSegments(text: text)
            ForEach(0..<segments.count, id: \.self) { index in
                let segment = segments[index]
                if segment.isCode {
                    CodeBlockView(code: segment.content, language: segment.language)
                } else {
                    // Call the helper function here
                    renderFormattedText(segment.content)
                }
            }
        }
    }

    // Helper function to handle the trimming logic
    @ViewBuilder
    private func renderFormattedText(_ content: String) -> some View {
        if let attr = try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            let trimmed = trimAttributedString(attr)
            Text(trimmed)
        } else {
            Text(content.trimmingCharacters(in: .newlines))
        }
    }

    private func trimAttributedString(_ attr: AttributedString) -> AttributedString {
        var trimmedAttr = attr
        while trimmedAttr.characters.first?.isNewline == true {
            trimmedAttr.characters.removeFirst()
        }
        while trimmedAttr.characters.last?.isNewline == true {
            trimmedAttr.characters.removeLast()
        }
        return trimmedAttr
    }

    // A simple parser to separate code blocks from prose
    private func parseMarkdownSegments(text: String) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        let parts = text.components(separatedBy: "```")
        
        for i in 0..<parts.count {
            let part = parts[i]
            if i % 2 == 1 { // Inside triple backticks
                let lines = part.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                let lang = String(lines.first ?? "").trimmingCharacters(in: .whitespaces)
                let code = lines.count > 1 ? String(lines[1]) : ""
                segments.append(MarkdownSegment(content: code, isCode: true, language: lang))
            } else { // Normal text
                if !part.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Extra formatting
                    let fullPart = part
                        .replacingOccurrences(of: "*   ", with: "•   ")
                    
                    segments.append(MarkdownSegment(content: fullPart, isCode: false))
                }
            }
        }
        return segments
    }
}

struct MarkdownSegment {
    let content: String
    let isCode: Bool
    var language: String = ""
}

struct CodeBlockView: View {
    let code: String
    let language: String
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Language and Copy Button
            HStack {
                Text(language.isEmpty ? "plaintext" : language)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: copyToClipboard) {
                    Label(isCopied ? "Copied!" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.1))

            // The Code Itself
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
            }
        }
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
        withAnimation { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
    }
}
