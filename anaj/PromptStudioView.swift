#if os(macOS)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Combine

struct PromptStudioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Prompt.timestamp, order: .reverse) private var prompts: [Prompt]
    @Query(sort: \Project.title) private var projects: [Project]
    
    // Global Settings (AppStorage)
    @AppStorage("openAIKey") private var openAIKey = ""
    @AppStorage("googleAPIKey") private var googleAPIKey = ""
    @AppStorage("selectedAIProvider") private var selectedProvider = AIProvider.local
    @AppStorage("selectedLocalModel") private var selectedLocalModel = "llama3"
    @AppStorage("ollamaBaseURL") private var ollamaBaseURL = "http://localhost:11434/api"
    @AppStorage("openClawBaseURL") private var openClawBaseURL = "http://127.0.0.1:18890"
    @AppStorage("openClawAPIKey") private var openClawAPIKey = ""
    @AppStorage("openClawStartupScriptPath") private var openClawStartupScriptPath = "/Users/jesse/anaj1/anaj/scripts/start-openclaw-bridge.sh"
    
    @State private var selectedPrompt: Prompt?
    @State private var searchText = ""
    @State private var showSettings = false
    @StateObject private var openClawBridge = OpenClawBridgeService()
    
    // Shared State for Local Models (passed to settings)
    @State private var availableLocalModels: [String] = []
    @State private var isCheckingOllama = false
    
    enum AIProvider: String, CaseIterable, Identifiable {
        case local = "Open Source"
        case openai = "OpenAI"
        case google = "Google"
        case openclaw = "OpenClaw"
        var id: String { rawValue }
    }
    
    var filteredPrompts: [Prompt] {
        if searchText.isEmpty { return prompts }
        return prompts.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.role.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Prompt Studio")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(6)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSettings) {
                        PromptStudioSettingsView(
                            openAIKey: $openAIKey,
                            googleAPIKey: $googleAPIKey,
                            openClawAPIKey: $openClawAPIKey,
                            selectedProvider: $selectedProvider,
                            selectedLocalModel: $selectedLocalModel,
                            ollamaBaseURL: $ollamaBaseURL,
                            openClawBaseURL: $openClawBaseURL,
                            openClawStartupScriptPath: $openClawStartupScriptPath,
                            availableLocalModels: $availableLocalModels,
                            isCheckingOllama: $isCheckingOllama,
                            fetchLocalModels: fetchLocalModels,
                            openClawBridge: openClawBridge
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20)
                
                // List
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(filteredPrompts) { prompt in
                            PromptListRow(prompt: prompt, isSelected: selectedPrompt?.id == prompt.id) {
                                selectedPrompt = prompt
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deletePrompt(prompt)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                
                // New Prompt Button
                Button(action: createPrompt) {
                    HStack {
                        Image(systemName: "plus")
                        Text("New Chat")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(20)
            }
            .frame(width: 260)
            .background(Color.black.opacity(0.1))
            
            // Chat / Editor Area
            Group {
                if let prompt = selectedPrompt {
                    ChatInterface(
                        prompt: prompt,
                        projects: projects,
                        openAIKey: openAIKey,
                        googleKey: googleAPIKey,
                        ollamaBaseURL: ollamaBaseURL,
                        openClawBaseURL: openClawBaseURL,
                        openClawAPIKey: openClawAPIKey,
                        provider: selectedProvider,
                        localModel: selectedLocalModel
                    )
                } else {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "Select or start a new chat",
                        message: "Choose a conversation from the sidebar or create a new one to get started."
                    )
                }
            }
            .background(AppColors.bgPrimary)
        }
        .onAppear {
            if selectedProvider == .local {
                fetchLocalModels()
            }
        }
        .onChange(of: selectedProvider) {
            if selectedProvider == .local {
                fetchLocalModels()
            } else if selectedProvider == .openclaw {
                Task {
                    await openClawBridge.refresh(baseURL: openClawBaseURL)
                }
            }
        }
        .onChange(of: showSettings) {
            guard showSettings, selectedProvider == .openclaw else { return }
            Task {
                await openClawBridge.refresh(baseURL: openClawBaseURL)
            }
        }
    }
    
    private func createPrompt() {
        let newPrompt = Prompt(title: "New Chat", content: "You are a helpful creative agency assistant.", role: "Assistant")
        modelContext.insert(newPrompt)
        try? modelContext.save()
        selectedPrompt = newPrompt
    }
    
    private func deletePrompt(_ prompt: Prompt) {
        if selectedPrompt?.id == prompt.id {
            selectedPrompt = nil
        }
        modelContext.delete(prompt)
        try? modelContext.save()
    }
    
    private func fetchLocalModels() {
        isCheckingOllama = true
        Task {
            do {
                let models = try await Ollama.fetchModels(baseURL: ollamaBaseURL)
                await MainActor.run {
                    self.availableLocalModels = models
                    if !models.contains(selectedLocalModel) && !models.isEmpty {
                        self.selectedLocalModel = models.first ?? "llama3"
                    }
                    self.isCheckingOllama = false
                }
            } catch {
                await MainActor.run {
                    self.availableLocalModels = [] 
                    self.isCheckingOllama = false
                }
            }
        }
    }
}

// MARK: - Chat Interface

struct ChatInterface: View {
    @Bindable var prompt: Prompt
    let projects: [Project]
    let openAIKey: String
    let googleKey: String
    let ollamaBaseURL: String
    let openClawBaseURL: String
    let openClawAPIKey: String
    let provider: PromptStudioView.AIProvider
    let localModel: String
    
    @Environment(\.modelContext) private var modelContext
    
    // State
    @State private var userInput: String = ""
    @State private var isRunning = false
    @State private var task: Task<Void, Never>?
    @State private var showSystemPrompt = true
    @State private var temperature: Double = 0.7
    @State private var includeProjectContext = false
    @State private var showInsightSummary = false
    @State private var aiSummaryDraft = ""
    @State private var isGeneratingSummary = false
    @State private var showManualInsight = false
    @State private var manualInsightContent = ""
    @State private var showInsightsPanel = false
    
    // Attachments
    @State private var isImporting = false
    @State private var selectedAttachments: [ProcessedAttachment] = []
    @State private var isProcessingFiles = false
    
    // Scrolling
    @Namespace private var bottomID
    
    var body: some View {
        VStack(spacing: 0) {
            // --- Toolbar ---
            HStack(spacing: 16) {
                TextField("Chat Title", text: $prompt.title)
                    .font(.system(size: 16, weight: .bold))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                
                Text(provider.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(.white.opacity(0.9))

                if provider == .openclaw {
                    Text("OpenClaw Route")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundStyle(.orange.opacity(0.95))
                }

                Spacer()

                // Project Linker
                Menu {
                    Button("No Project") { prompt.project = nil }
                    ForEach(projects) { project in
                        Button(action: { prompt.project = project }) {
                            HStack {
                                Circle().fill(Color(hex: project.accentHex) ?? .white).frame(width: 8, height: 8)
                                Text(project.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let project = prompt.project {
                            Circle().fill(Color(hex: project.accentHex) ?? .white).frame(width: 8, height: 8)
                            Text(project.title).foregroundStyle(.white)
                        } else {
                            Image(systemName: "folder")
                            Text("Link Project").foregroundStyle(.white.opacity(0.6))
                        }
                        Image(systemName: "chevron.down").font(.system(size: 10))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)

                if prompt.project != nil {
                    Toggle(isOn: $includeProjectContext) {
                        Image(systemName: "brain.head.profile")
                            .help("Include project context in AI prompts")
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.plain)
                    .padding(6)
                    .background(includeProjectContext ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                    .clipShape(Circle())
                }

                Button(action: summarizeChat) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(8)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Summarize Chat as Insight")
                .disabled(isRunning || prompt.messages.count < 2)
                .sheet(isPresented: $showInsightSummary) {
                    InsightSummaryModal(
                        draft: $aiSummaryDraft,
                        isGenerating: isGeneratingSummary,
                        onSave: saveAISummary,
                        onCancel: { showInsightSummary = false }
                    )
                }
                
                Button(action: { withAnimation { showSystemPrompt.toggle() } }) {
                    Image(systemName: showSystemPrompt ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(8)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Toggle System Prompt")
                
                if isRunning {
                    Button(action: stopGeneration) {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.2))
            
            // --- System Prompt Section (Collapsible) ---
            if showSystemPrompt {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("SYSTEM / CONTEXT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                    }
                    
                    // Skills Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Skill.all) { skill in
                                Button(action: {
                                    withAnimation {
                                        prompt.role = skill.name
                                        prompt.content = skill.prompt
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: skill.icon)
                                        Text(skill.name)
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(prompt.role == skill.name ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                                    .foregroundStyle(prompt.role == skill.name ? .blue : .white.opacity(0.7))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(prompt.role == skill.name ? Color.blue.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                    
                    TextEditor(text: $prompt.content)
                        .font(.system(size: 12, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(height: 100)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(12)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1), lineWidth: 1))
                }
                .padding(16)
                .background(Color.black.opacity(0.1))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // --- Insights Panel ---
            VStack(alignment: .leading, spacing: 0) {
                Button(action: { withAnimation { showInsightsPanel.toggle() } }) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text("CHAT INSIGHTS")
                            .font(.system(size: 10, weight: .bold))
                        Text("(\(prompt.insights.count))")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Image(systemName: showInsightsPanel ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                }
                .buttonStyle(.plain)
                
                if showInsightsPanel {
                    if prompt.insights.isEmpty {
                        Text("No insights extracted yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(prompt.insights.sorted(by: { $0.timestamp > $1.timestamp })) { insight in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(insight.title)
                                                .font(.system(size: 12, weight: .bold))
                                                .lineLimit(1)
                                            Spacer()
                                            Button(action: { deleteInsight(insight) }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.white.opacity(0.3))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        Text(insight.content)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .lineLimit(3)
                                    }
                                    .padding(12)
                                    .frame(width: 200)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .background(Color.black.opacity(0.15))
            
            // --- Chat History ---
            MessageListView(
                promptID: prompt.id,
                isRunning: isRunning,
                onSaveAsInsight: { content in
                    manualInsightContent = content
                    showManualInsight = true
                }
            )
            .sheet(isPresented: $showManualInsight) {
                InsightSummaryModal(
                    draft: $manualInsightContent,
                    isGenerating: false,
                    onSave: saveManualInsight,
                    onCancel: { showManualInsight = false }
                )
            }
            
            // --- Input Area ---
            VStack(spacing: 0) {
                Divider().background(.white.opacity(0.1))
                
                // Attachment Preview Bar
                if !selectedAttachments.isEmpty || isProcessingFiles {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            if isProcessingFiles {
                                ProgressView().controlSize(.small)
                                Text("Processing...").font(.caption).foregroundStyle(.white.opacity(0.5))
                            }
                            ForEach(selectedAttachments) { file in
                                HStack(spacing: 6) {
                                    if let img = file.previewImage {
                                        Image(nsImage: img)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 24, height: 24)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    } else {
                                        Image(systemName: "doc.text")
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    
                                    Text(file.name)
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    
                                    Button(action: {
                                        if let index = selectedAttachments.firstIndex(where: { $0.id == file.id }) {
                                            selectedAttachments.remove(at: index)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
                
                HStack(alignment: .bottom, spacing: 12) {
                    // Attachment Button
                    Button(action: { isImporting = true }) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(height: 32)
                    }
                    .buttonStyle(.plain)
                    .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf, .text, .image, .sourceCode], allowsMultipleSelection: true) { result in
                        handleImport(result)
                    }
                    
                    ZStack(alignment: .leading) {
                        if userInput.isEmpty {
                            Text("Send a message...")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                        
                        HighPerformanceTextInput(
                            text: $userInput,
                            placeholder: "Send a message...",
                            onSubmit: sendMessage
                        )
                        .frame(minHeight: 40, maxHeight: 150)
                        .padding(6)
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(userInput.isEmpty && selectedAttachments.isEmpty ? .gray : .blue)
                            .background(Circle().fill(.white).padding(2))
                    }
                    .buttonStyle(.plain)
                    .disabled((userInput.isEmpty && selectedAttachments.isEmpty) || isRunning || isProcessingFiles)
                }
                .padding(20)
                .background(Color.black.opacity(0.2))
            }
        }
    }
    
    // --- Logic ---
    
    private func handleImport(_ result: Result<[URL], Error>) {
        isProcessingFiles = true
        switch result {
        case .success(let urls):
            Task {
                let attachments = await DocumentProcessor.process(urls: urls)
                await MainActor.run {
                    self.selectedAttachments.append(contentsOf: attachments)
                    self.isProcessingFiles = false
                }
            }
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
            isProcessingFiles = false
        }
    }
    
    private func stopGeneration() {
        task?.cancel()
        isRunning = false
    }

    private func summarizeChat() {
        showInsightSummary = true
        isGeneratingSummary = true
        aiSummaryDraft = ""
        
        Task {
            do {
                let history = prompt.messages.sorted { $0.timestamp < $1.timestamp }
                var chatText = ""
                for msg in history {
                    chatText += "\(msg.role.uppercased()): \(msg.content)\n\n"
                }
                
                let summaryPrompt = "Please summarize the key information, decisions, and action items from the following conversation into a concise bulleted list. Return ONLY the summary.\n\nCONVERSATION:\n\(chatText)"
                
                var response = ""
                if provider == .local {
                    // Non-streaming for summary
                    for try await chunk in Ollama.chatStream(baseURL: ollamaBaseURL, model: localModel, messages: [ChatMessage(role: "user", content: summaryPrompt)], system: "You are a precise business analyst.", temperature: 0.3) {
                        response += chunk
                    }
                } else if provider == .openai {
                    response = try await OpenAI.chatCompletion(apiKey: openAIKey, messages: [ChatMessage(role: "user", content: summaryPrompt)], system: "You are a precise business analyst.")
                } else if provider == .google {
                    response = try await GoogleAI.generateContent(apiKey: googleKey, prompt: summaryPrompt)
                } else if provider == .openclaw {
                    response = try await OpenClawProvider.generateContent(
                        baseURL: openClawBaseURL,
                        apiKey: openClawAPIKey,
                        prompt: summaryPrompt,
                        system: "You are a precise business analyst."
                    )
                }
                
                await MainActor.run {
                    self.aiSummaryDraft = response
                    self.isGeneratingSummary = false
                }
            } catch {
                await MainActor.run {
                    self.aiSummaryDraft = "Error generating summary: \(error.localizedDescription)"
                    self.isGeneratingSummary = false
                }
            }
        }
    }

    private func saveAISummary() {
        let history = prompt.messages.sorted { $0.timestamp < $1.timestamp }
        let messageIDs = history.map { $0.id }
        let providerName = provider.rawValue
        
        let insight = ChatInsight(
            title: "AI Summary: \(prompt.title)", 
            content: aiSummaryDraft, 
            source: .aiSummary,
            type: .summary,
            sourceMessageIDs: messageIDs,
            providerLabel: providerName
        )
        insight.prompt = prompt
        insight.project = prompt.project
        modelContext.insert(insight)
        try? modelContext.save()
        showInsightSummary = false
        withAnimation { showInsightsPanel = true }
    }

    private func saveManualInsight() {
        let insight = ChatInsight(
            title: "Manual Insight", 
            content: manualInsightContent, 
            source: .manualSelection,
            type: .note,
            providerLabel: "Manual"
        )
        insight.prompt = prompt
        insight.project = prompt.project
        modelContext.insert(insight)
        try? modelContext.save()
        showManualInsight = false
        withAnimation { showInsightsPanel = true }
    }

    private func deleteInsight(_ insight: ChatInsight) {
        modelContext.delete(insight)
        try? modelContext.save()
    }
    
    private func sendMessage() {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedAttachments.isEmpty else { return }
        
        var userMsgContent = userInput
        userInput = ""
        
        // --- Process Attachments ---
        // 1. Docs: Append text to content
        let docs = selectedAttachments.filter { $0.type == .document }
        if !docs.isEmpty {
            var contextString = "\n\n--- ATTACHED DOCUMENTS ---\n"
            for doc in docs {
                if let content = doc.content {
                    contextString += "Filename: \(doc.name)\nContent:\n\(content)\n\n"
                }
            }
            contextString += "--- END ATTACHMENTS ---\n"
            userMsgContent += contextString
        }
        
        // 2. Serialize Attachments for Storage
        let codableAttachments = selectedAttachments.map { $0.toCodable() }
        let attachmentsJSON = try? JSONEncoder().encode(codableAttachments)
        let attachmentsString = attachmentsJSON.flatMap { String(data: $0, encoding: .utf8) }
        
        // 3. Images for API
        let images = selectedAttachments.filter { $0.type == .image }.compactMap { $0.content }
        
        // Reset attachments
        selectedAttachments = []
        
        // --- Save to DB ---
        let userMsg = ChatMessage(role: "user", content: userMsgContent, attachmentsJSON: attachmentsString)
        userMsg.prompt = prompt
        prompt.messages.append(userMsg)
        
        let assistantMsg = ChatMessage(role: "assistant", content: "")
        assistantMsg.prompt = prompt
        prompt.messages.append(assistantMsg)
        
        try? modelContext.save()
        
        // ... (Rest of stream logic is fine)
        // --- Stream ---
        isRunning = true
        
        task = Task {
            do {
                var systemCtx = prompt.content
                
                // --- Project Context Injection ---
                if includeProjectContext, let project = prompt.project {
                    var contextString = "\n\n--- PROJECT CONTEXT ---\n"
                    contextString += "Project: \(project.title)\n"
                    if let client = project.client {
                        contextString += "Client: \(client.name)\n"
                    }
                    contextString += "Status: \(project.status.rawValue)\n"
                    
                    let activeTasks = project.tasks.filter { !$0.isDone }
                    if !activeTasks.isEmpty {
                        contextString += "Active Tasks:\n"
                        for task in activeTasks.prefix(5) {
                            contextString += "- \(task.content)\n"
                        }
                    }
                    contextString += "--- END CONTEXT ---\n"
                    systemCtx += contextString
                }

                let history = prompt.messages.sorted { $0.timestamp < $1.timestamp }
                
                if provider == .local {
                    var buffer = ""
                    var lastUpdate = Date()
                    for try await chunk in Ollama.chatStream(baseURL: ollamaBaseURL, model: localModel, messages: history, system: systemCtx, temperature: temperature, images: images) {
                        if Task.isCancelled { break }
                        buffer += chunk
                        if -lastUpdate.timeIntervalSinceNow > 0.05 {
                            let textToAppend = buffer
                            buffer = ""
                            lastUpdate = Date()
                            await MainActor.run { assistantMsg.content += textToAppend }
                        }
                    }
                    if !buffer.isEmpty { await MainActor.run { assistantMsg.content += buffer } }
                    
                } else if provider == .openai {
                     let response = try await OpenAI.chatCompletion(apiKey: openAIKey, messages: history, system: systemCtx, images: images)
                     await MainActor.run { assistantMsg.content = response }
                } else if provider == .google {
                    let response = try await GoogleAI.generateContent(apiKey: googleKey, prompt: userMsgContent, images: images)
                    await MainActor.run { assistantMsg.content = response }
                } else if provider == .openclaw {
                    let response = try await OpenClawProvider.chatCompletion(
                        baseURL: openClawBaseURL,
                        apiKey: openClawAPIKey,
                        messages: history,
                        system: systemCtx,
                        prompt: userMsgContent
                    )
                    await MainActor.run { assistantMsg.content = response }
                }
                
                await MainActor.run {
                    isRunning = false
                    try? modelContext.save()
                }
                
            } catch {
                await MainActor.run {
                    assistantMsg.content += "\n[Error: \(error.localizedDescription)]"
                    isRunning = false
                    try? modelContext.save()
                }
            }
        }
    }
}

// ... (Ollama struct remains same) ...

struct MessageListView: View {
    @Query var messages: [ChatMessage]
    var isRunning: Bool
    var onSaveAsInsight: (String) -> Void
    
    init(promptID: UUID, isRunning: Bool, onSaveAsInsight: @escaping (String) -> Void) {
        self.isRunning = isRunning
        self.onSaveAsInsight = onSaveAsInsight
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.prompt?.id == promptID },
            sort: \.timestamp
        )
    }
    
    @Namespace private var bottomID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    Color.clear.frame(height: 10)
                    
                    if messages.isEmpty {
                        Text("Start the conversation below.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.top, 40)
                    }
                    
                    ForEach(messages) { msg in
                        ChatBubble(message: msg, onSaveAsInsight: onSaveAsInsight)
                    }
                    
                    Color.clear.frame(height: 1).id(bottomID)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .onChange(of: messages.count) {
                withAnimation { proxy.scrollTo(bottomID, anchor: .bottom) }
            }
            .onChange(of: isRunning) {
                if isRunning { withAnimation { proxy.scrollTo(bottomID, anchor: .bottom) } }
            }
            .onAppear {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    var onSaveAsInsight: (String) -> Void = { _ in }
    
    var role: String { message.role }
    var content: String { message.content }
    var isUser: Bool { role == "user" }
    
    @State private var isExpanded = false
    private let truncationThreshold = 20000
    
    private var isTruncated: Bool {
        content.count > truncationThreshold
    }
    
    private var displayedContent: String {
        if isTruncated && !isExpanded {
            return String(content.prefix(truncationThreshold)) + "..."
        }
        return content
    }
    
    private var segments: [MessageSegment] {
        MessageParser.parse(displayedContent)
    }
    
    var attachments: [CodableAttachment] {
        guard let json = message.attachmentsJSON,
              let data = json.data(using: .utf8),
              let list = try? JSONDecoder().decode([CodableAttachment].self, from: data) else { return [] }
        return list
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isUser { Spacer() }
            
            assistantAvatar
            
            bubbleContent
            
            userAvatar
            
            if !isUser { Spacer() }
        }
        .contextMenu {
            Button {
                onSaveAsInsight(content)
            } label: {
                Label("Save as Insight", systemImage: "lightbulb.fill")
            }
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(content, forType: .string)
            } label: {
                Label("Copy Message", systemImage: "doc.on.doc")
            }
        }
    }
    
    // MARK: - Sub-views
    
    @ViewBuilder
    private var assistantAvatar: some View {
        if !isUser {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "cpu").font(.system(size: 14)).foregroundStyle(.orange))
        }
    }
    
    @ViewBuilder
    private var userAvatar: some View {
        if isUser {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: "person.fill").font(.system(size: 14)).foregroundStyle(.blue))
        }
    }
    
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            attachmentsGrid
            messageContent
        }
        .padding(12)
        .background(isUser ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
        .frame(maxWidth: 700, alignment: isUser ? .trailing : .leading)
    }
    
    @ViewBuilder
    private var attachmentsGrid: some View {
        if !attachments.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(attachments) { att in
                    AttachmentThumbnail(attachment: att)
                }
            }
            .padding(.bottom, 4)
        }
    }
    
    @ViewBuilder
    private var messageContent: some View {
        if !isUser && content.isEmpty {
            loadingIndicator
        } else {
            segmentedContent
            truncationButton
        }
    }
    
    private var loadingIndicator: some View {
        HStack(spacing: 4) {
            Circle().fill(.white.opacity(0.5)).frame(width: 6, height: 6)
            Circle().fill(.white.opacity(0.5)).frame(width: 6, height: 6)
            Circle().fill(.white.opacity(0.5)).frame(width: 6, height: 6)
        }
        .padding(8)
    }
    
    private var segmentedContent: some View {
        ForEach(segments.indices, id: \.self) { index in
            SegmentView(segment: segments[index])
        }
    }
    
    @ViewBuilder
    private var truncationButton: some View {
        if isTruncated {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                Text(isExpanded ? "Show Less" : "Show More (\(content.count) characters)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

// MARK: - ChatBubble Sub-Components

struct AttachmentThumbnail: View {
    let attachment: CodableAttachment
    
    var body: some View {
        if attachment.type == .image, let base64 = attachment.content,
           let data = Data(base64Encoded: base64),
           let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            HStack {
                Image(systemName: "doc.fill")
                Text(attachment.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SegmentView: View {
    let segment: MessageSegment
    
    var body: some View {
        switch segment {
        case .text(let text):
            textContent(text)
        case .code(let lang, let code):
            CodeBlockView(language: lang, code: code)
        }
    }
    
    @ViewBuilder
    private func textContent(_ text: String) -> some View {
        if text.count < 5000 {
            Text(LocalizedStringKey(text))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(4)
                .textSelection(.enabled)
        } else {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Code Block Components

// CodeBlockView is now in DesignSystem/CodeBlockView.swift

enum MessageSegment {
    case text(String)
    case code(String, String)
}

struct MessageParser {
    static func parse(_ content: String) -> [MessageSegment] {
        var segments: [MessageSegment] = []
        let pattern = "```(\\w+)?\\n([\\s\\S]*?)```" // Regex for code blocks
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { 
            return [.text(content)]
        }
        
        let nsString = content as NSString
        var lastIndex = 0
        
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            // Text before code
            if match.range.location > lastIndex {
                let textRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                segments.append(.text(nsString.substring(with: textRange)))
            }
            
            // Language
            var lang = ""
            if match.range(at: 1).location != NSNotFound {
                lang = nsString.substring(with: match.range(at: 1))
            }
            
            // Code
            if match.range(at: 2).location != NSNotFound {
                let code = nsString.substring(with: match.range(at: 2))
                segments.append(.code(lang, code.trimmingCharacters(in: .newlines)))
            }
            
            lastIndex = match.range.location + match.range.length
        }
        
        // Remaining text
        if lastIndex < nsString.length {
            segments.append(.text(nsString.substring(from: lastIndex)))
        }
        
        return segments.isEmpty ? [.text(content)] : segments
    }
}

// MARK: - API Helpers & Subviews

struct HighPerformanceTextInput: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .white
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.insertionPointColor = .white
        
        // Hide scroll indicators for a cleaner look
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighPerformanceTextInput
        private var debounceTask: Task<Void, Never>?
        
        init(_ parent: HighPerformanceTextInput) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string
            
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                parent.text = newText
            }
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSStandardKeyBindingResponding.insertNewline(_:)) {
                let event = NSApp.currentEvent
                if event?.modifierFlags.contains(.shift) == true {
                    // Shift+Enter: Insert newline
                    return false
                } else {
                    // Enter: Submit
                    parent.onSubmit()
                    return true
                }
            }
            return false
        }
    }
}

struct InsightSummaryModal: View {
    @Binding var draft: String
    let isGenerating: Bool
    var onSave: () -> Void
    var onCancel: () -> Void
    
    @State private var editedTitle: String = "Chat Insight"
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Save Chat Insight")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            
            VStack(alignment: .leading, spacing: 15) {
                if isGenerating {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Analyzing conversation...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    TextField("Title", text: $editedTitle)
                        .textFieldStyle(.roundedBorder)
                    
                    TextEditor(text: $draft)
                        .font(.system(size: 13))
                        .frame(height: 200)
                        .padding(8)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save Insight") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating || draft.isEmpty)
            }
            .padding()
        }
        .frame(width: 450)
        .background(Color.black.opacity(0.8))
    }
}

struct Ollama {
    struct OllamaModelResponse: Decodable { let models: [OllamaModel] }
    struct OllamaModel: Decodable { let name: String }
    
    static func fetchModels(baseURL: String) async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/tags") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(OllamaModelResponse.self, from: data)
        return decoded.models.map { $0.name }
    }
    
    static func generateTitle(baseURL: String, model: String, prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/generate") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "prompt": "Summarize this in 3 to 5 words for a chat title. Do not use quotes: \(prompt)",
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let response = json["response"] as? String {
            return response
        }
        return "New Chat"
    }
    
    static func chatStream(baseURL: String, model: String, messages: [ChatMessage], system: String, temperature: Double, images: [String] = []) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let url = URL(string: "\(baseURL)/chat") else {
                    continuation.finish(throwing: URLError(.badURL)); return
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                var apiMessages: [[String: Any]] = []
                if !system.isEmpty { apiMessages.append(["role": "system", "content": system]) }
                for msg in messages where !msg.content.isEmpty {
                    apiMessages.append(["role": msg.role, "content": msg.content])
                }
                if !images.isEmpty, var lastMsg = apiMessages.popLast() {
                    lastMsg["images"] = images
                    apiMessages.append(lastMsg)
                }
                
                let body: [String: Any] = ["model": model, "messages": apiMessages, "temperature": temperature, "stream": true]
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: URLError(.badServerResponse)); return
                    }
                    for try await line in bytes.lines {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = json["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            continuation.yield(content)
                            if let done = json["done"] as? Bool, done { continuation.finish(); return }
                        }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }
}

struct OpenAI {
    static func chatCompletion(apiKey: String, messages: [ChatMessage], system: String, images: [String] = []) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var apiMessages: [[String: Any]] = []
        apiMessages.append(["role": "system", "content": system])
        
        for msg in messages where !msg.content.isEmpty {
            apiMessages.append(["role": msg.role, "content": msg.content])
        }
        
        // Attach images to the last message if available
        if !images.isEmpty, var lastMsg = apiMessages.popLast(), let lastContent = lastMsg["content"] as? String {
            var contentArray: [[String: Any]] = [
                ["type": "text", "text": lastContent]
            ]
            
            for base64 in images {
                contentArray.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                ])
            }
            lastMsg["content"] = contentArray
            apiMessages.append(lastMsg)
        }
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 4000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let err = String(data: data, encoding: .utf8) ?? "Unknown"; throw NSError(domain: "OpenAI", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]], let first = choices.first,
           let msg = first["message"] as? [String: Any], let content = msg["content"] as? String { return content }
        throw URLError(.cannotParseResponse)
    }
}

struct GoogleAI {
    static func generateContent(apiKey: String, prompt: String, images: [String] = []) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=\(apiKey)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var parts: [[String: Any]] = [["text": prompt]]
        
        for base64 in images {
            parts.append([
                "inlineData": [
                    "mimeType": "image/jpeg",
                    "data": base64
                ]
            ])
        }
        
        let body: [String: Any] = ["contents": [["parts": parts]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
             let err = String(data: data, encoding: .utf8) ?? "Unknown"; throw NSError(domain: "Google", code: 0, userInfo: [NSLocalizedDescriptionKey: err])
        }
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]], let first = candidates.first,
           let content = first["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let part = parts.first, let text = part["text"] as? String { return text }
        throw URLError(.cannotParseResponse)
    }
}

struct OpenClawProvider {
    private static func chatURLCandidates(baseURL: String) -> [URL] {
        let trimmed = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !trimmed.isEmpty else { return [] }

        var candidates: [String] = ["\(trimmed)/chat"]
        if trimmed.lowercased().hasSuffix("/api") {
            let root = String(trimmed.dropLast(4)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !root.isEmpty {
                candidates.append("\(root)/chat")
            }
        }

        var seen = Set<String>()
        return candidates.compactMap { value in
            let key = value.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return URL(string: value)
        }
    }

    private static func postChat(baseURL: String, apiKey: String, body: [String: Any]) async throws -> [String: Any] {
        let urls = chatURLCandidates(baseURL: baseURL)
        guard !urls.isEmpty else { throw URLError(.badURL) }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        var lastError: Error = URLError(.badServerResponse)

        for (index, url) in urls.enumerated() {
            do {
                var request = authorizedRequest(url: url, apiKey: apiKey)
                request.httpBody = bodyData

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                if (200...299).contains(http.statusCode) {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw URLError(.cannotParseResponse)
                    }
                    return json
                }

                let raw = String(data: data, encoding: .utf8) ?? "OpenClaw request failed"
                let err = await friendlyHTTPError(
                    statusCode: http.statusCode,
                    baseURL: baseURL,
                    rawMessage: raw
                )
                let statusError = NSError(
                    domain: "OpenClaw",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: err]
                )
                lastError = statusError

                let hasNext = index < urls.count - 1
                if http.statusCode == 404 && hasNext {
                    continue
                }
                throw statusError
            } catch {
                let mapped = await mapTransportError(error, baseURL: baseURL)
                lastError = mapped
                let hasNext = index < urls.count - 1
                if hasNext {
                    continue
                }
                throw mapped
            }
        }

        throw lastError
    }

    private static func authorizedRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private static func mapTransportError(_ error: Error, baseURL: String) async -> Error {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .timedOut:
                return NSError(
                    domain: "OpenClaw",
                    code: urlError.errorCode,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot reach OpenClaw at \(baseURL). Start the bridge with \"Connect OpenClaw\" and verify the endpoint."]
                )
            default:
                break
            }
        }
        return error
    }

    private static func friendlyHTTPError(statusCode: Int, baseURL: String, rawMessage: String) async -> String {
        if statusCode == 404 {
            if await isANAJLocalAPI(baseURL: baseURL) {
                return "OpenClaw route not found at \(baseURL). This URL points to ANAJ local API on port 18790. Switch to http://127.0.0.1:18890 or use Connect OpenClaw."
            }
            return "OpenClaw /chat route not found at \(baseURL). Ensure the bridge backend is running on port 18890."
        }

        if statusCode == 502 {
            return "OpenClaw bridge reached but upstream failed: \(rawMessage)"
        }

        if statusCode == 503 {
            return "OpenClaw bridge is unavailable. Start backend and retry."
        }

        return rawMessage
    }

    private static func isANAJLocalAPI(baseURL: String) async -> Bool {
        let normalized = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(normalized)/api/health") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            let service = (json["service"] as? String)?.lowercased()
            if service == "anaj-api" {
                return true
            }
            let status = (json["status"] as? String)?.lowercased()
            let port = json["port"] as? Int
            return status == "ok" && port == 18790
        } catch {
            return false
        }
    }

    static func generateContent(baseURL: String, apiKey: String, prompt: String, system: String) async throws -> String {
        let body: [String: Any] = [
            "prompt": prompt,
            "system": system
        ]

        let json = try await postChat(baseURL: baseURL, apiKey: apiKey, body: body)
        if let content = json["content"] as? String { return content }
        if let message = json["message"] as? String { return message }
        if let response = json["response"] as? String { return response }

        throw URLError(.cannotParseResponse)
    }

    static func chatCompletion(baseURL: String, apiKey: String, messages: [ChatMessage], system: String, prompt: String) async throws -> String {
        let history: [[String: String]] = messages
            .filter { !$0.content.isEmpty }
            .map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "prompt": prompt,
            "system": system,
            "messages": history
        ]
        let json = try await postChat(baseURL: baseURL, apiKey: apiKey, body: body)
        if let content = json["content"] as? String { return content }
        if let message = json["message"] as? String { return message }
        if let response = json["response"] as? String { return response }
        if let result = json["result"] as? [String: Any], let content = result["content"] as? String { return content }

        throw URLError(.cannotParseResponse)
    }
}

@MainActor
final class OpenClawBridgeService: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case starting
        case connected
        case failed
    }

    @Published var state: ConnectionState = .disconnected
    @Published var details: String = "Bridge is not connected."
    @Published var showsLegacyPortFix = false

    private var process: Process?
    private var logBuffer = ""

    func refresh(baseURL: String) async {
        let normalized = normalize(baseURL: baseURL)
        guard !normalized.isEmpty else {
            state = .disconnected
            details = "Set an OpenClaw endpoint first."
            showsLegacyPortFix = false
            return
        }

        if await isReady(baseURL: normalized) {
            state = .connected
            details = "OpenClaw bridge is reachable."
            showsLegacyPortFix = false
            return
        }

        state = .disconnected
        details = "OpenClaw bridge is not reachable."
        showsLegacyPortFix = await detectLegacyPortConflict(baseURL: normalized)
    }

    func connect(baseURL: String, startupScriptPath: String) async {
        let normalized = normalize(baseURL: baseURL)
        guard !normalized.isEmpty else {
            state = .failed
            details = "OpenClaw endpoint is empty."
            return
        }

        state = .starting
        details = "Starting backend..."
        showsLegacyPortFix = false

        if await isReady(baseURL: normalized) {
            state = .connected
            details = "OpenClaw bridge is already running."
            return
        }

        let scriptURL = URL(fileURLWithPath: startupScriptPath)
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            state = .failed
            details = "Startup script not found at \(startupScriptPath)"
            return
        }

        do {
            try launchBridge(scriptPath: scriptURL.path)
        } catch {
            state = .failed
            details = "Failed to start backend: \(error.localizedDescription)"
            return
        }

        let ready = await waitUntilReady(baseURL: normalized, timeoutSeconds: 15)
        if ready {
            state = .connected
            details = "Connected to OpenClaw bridge at \(normalized)."
            showsLegacyPortFix = false
            return
        }

        state = .failed
        let logTail = trimmedLogTail(limit: 420)
        if logTail.isEmpty {
            details = "Backend did not become ready in time."
        } else {
            details = "Backend did not become ready in time.\n\(logTail)"
        }
        showsLegacyPortFix = await detectLegacyPortConflict(baseURL: normalized)
    }

    private func launchBridge(scriptPath: String) throws {
        if let process, process.isRunning {
            return
        }

        logBuffer = ""
        let next = Process()
        next.executableURL = URL(fileURLWithPath: "/bin/zsh")
        next.arguments = [scriptPath]

        var env = ProcessInfo.processInfo.environment
        env["OPENCLAW_BRIDGE_PORT"] = "18890"
        next.environment = env

        let pipe = Pipe()
        next.standardOutput = pipe
        next.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                self?.appendLog(text)
            }
        }

        try next.run()
        process = next
    }

    private func appendLog(_ text: String) {
        logBuffer += text
        if logBuffer.count > 6000 {
            logBuffer = String(logBuffer.suffix(6000))
        }
    }

    private func trimmedLogTail(limit: Int) -> String {
        String(logBuffer.suffix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func waitUntilReady(baseURL: String, timeoutSeconds: Double) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if await isReady(baseURL: baseURL) {
                return true
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }

    private func isReady(baseURL: String) async -> Bool {
        guard await healthCheck(baseURL: baseURL) else { return false }
        return await chatRouteExists(baseURL: baseURL)
    }

    private func healthCheck(baseURL: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/health") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    private func chatRouteExists(baseURL: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/chat") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            if http.statusCode == 404 { return false }
            if http.statusCode == 405 { return false }
            return true
        } catch {
            return false
        }
    }

    private func detectLegacyPortConflict(baseURL: String) async -> Bool {
        let lowered = baseURL.lowercased()
        guard lowered.contains("127.0.0.1:18790") || lowered.contains("localhost:18790") else {
            return false
        }

        guard await isANAJLocalAPI(baseURL: baseURL) else { return false }
        guard let chatURL = URL(string: "\(baseURL)/chat") else { return false }

        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 2
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 404
        } catch {
            return false
        }
    }

    private func isANAJLocalAPI(baseURL: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/health") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            let service = (json["service"] as? String)?.lowercased()
            if service == "anaj-api" {
                return true
            }
            let status = (json["status"] as? String)?.lowercased()
            let port = json["port"] as? Int
            return status == "ok" && port == 18790
        } catch {
            return false
        }
    }

    private func normalize(baseURL: String) -> String {
        baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

private extension OpenClawBridgeService.ConnectionState {
    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .starting: return "Starting..."
        case .connected: return "Connected"
        case .failed: return "Failed"
        }
    }

    var iconName: String {
        switch self {
        case .disconnected: return "bolt.slash.fill"
        case .starting: return "hourglass"
        case .connected: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .disconnected: return .secondary
        case .starting: return .orange
        case .connected: return .green
        case .failed: return .red
        }
    }
}

struct PromptStudioSettingsView: View {
    @Binding var openAIKey: String
    @Binding var googleAPIKey: String
    @Binding var openClawAPIKey: String
    @Binding var selectedProvider: PromptStudioView.AIProvider
    @Binding var selectedLocalModel: String
    @Binding var ollamaBaseURL: String
    @Binding var openClawBaseURL: String
    @Binding var openClawStartupScriptPath: String
    @Binding var availableLocalModels: [String]
    @Binding var isCheckingOllama: Bool
    var fetchLocalModels: () -> Void
    @ObservedObject var openClawBridge: OpenClawBridgeService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Provider").font(.caption).foregroundStyle(.secondary)
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(PromptStudioView.AIProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }
            Divider()
            if selectedProvider == .openai {
                SecureInput(title: "OpenAI API Key", text: $openAIKey, color: .green)
            } else if selectedProvider == .google {
                SecureInput(title: "Google API Key", text: $googleAPIKey, color: .blue)
            } else if selectedProvider == .openclaw {
                VStack(alignment: .leading, spacing: 10) {
                    Text("OpenClaw Endpoint").font(.caption).foregroundStyle(.secondary)
                    TextField("http://127.0.0.1:18890", text: $openClawBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    Text("Startup Script").font(.caption).foregroundStyle(.secondary)
                    TextField("/Users/jesse/anaj1/anaj/scripts/start-openclaw-bridge.sh", text: $openClawStartupScriptPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption2)

                    SecureInput(title: "OpenClaw API Key (Optional)", text: $openClawAPIKey, color: .orange)

                    HStack(spacing: 8) {
                        Button {
                            Task {
                                await openClawBridge.connect(
                                    baseURL: openClawBaseURL,
                                    startupScriptPath: openClawStartupScriptPath
                                )
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if openClawBridge.state == .starting {
                                    ProgressView().controlSize(.small)
                                    Text("Starting...")
                                } else {
                                    Image(systemName: "power.circle.fill")
                                    Text("Connect OpenClaw")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(openClawBridge.state == .starting)

                        Button("Recheck") {
                            Task {
                                await openClawBridge.refresh(baseURL: openClawBaseURL)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(openClawBridge.state == .starting)
                    }

                    Label(openClawBridge.state.label, systemImage: openClawBridge.state.iconName)
                        .font(.caption)
                        .foregroundStyle(openClawBridge.state.tint)

                    if !openClawBridge.details.isEmpty {
                        Text(openClawBridge.details)
                            .font(.caption2)
                            .foregroundStyle(openClawBridge.state == .failed ? .red : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if openClawBridge.showsLegacyPortFix {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("This URL points to ANAJ API on port 18790. Switch OpenClaw endpoint to 18890.")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Button("Switch to http://127.0.0.1:18890") {
                                openClawBaseURL = "http://127.0.0.1:18890"
                                Task {
                                    await openClawBridge.refresh(baseURL: openClawBaseURL)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ollama Connection").font(.caption).foregroundStyle(.secondary)
                    TextField("http://localhost:11434/api", text: $ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    
                    HStack {
                        Text("Model").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if isCheckingOllama { ProgressView().controlSize(.mini) } 
                        else { Button(action: fetchLocalModels) { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain) }
                    }
                    if availableLocalModels.isEmpty {
                        TextField("e.g. llama3", text: $selectedLocalModel).textFieldStyle(.roundedBorder)
                    } else {
                        Picker("Model", selection: $selectedLocalModel) {
                            ForEach(availableLocalModels, id: \.self) { model in Text(model).tag(model) }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 300)
        .task(id: selectedProvider) {
            guard selectedProvider == .openclaw else { return }
            await openClawBridge.refresh(baseURL: openClawBaseURL)
        }
        .onChange(of: openClawBaseURL) {
            guard selectedProvider == .openclaw else { return }
            Task {
                await openClawBridge.refresh(baseURL: openClawBaseURL)
            }
        }
    }
}

struct SecureInput: View {
    let title: String; @Binding var text: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            SecureField("sk-...", text: $text).textFieldStyle(.roundedBorder)
        }
    }
}

struct PromptListRow: View {
    let prompt: Prompt; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title.isEmpty ? "Untitled" : prompt.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? .black : .white)
                    Text(prompt.messages.last?.content ?? prompt.role)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .black.opacity(0.7) : .white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skills Model
struct Skill: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let prompt: String
    
    static let all: [Skill] = [
        Skill(name: "SwiftUI Expert", icon: "swift", prompt: "You are a Senior iOS Engineer expert in SwiftUI, SwiftData, and Clean Architecture. Write idiomatic, performant, and thread-safe code. Prefer struct-based views and Observation framework."),
        Skill(name: "UX Designer", icon: "paintbrush.fill", prompt: "You are a world-class Product Designer. Focus on aesthetics, accessibility, whitespace, and glassmorphism. Provide hex codes and animation curves."),
        Skill(name: "Tech Lead", icon: "person.3.fill", prompt: "You are a CTO. Analyze problems from a high-level architecture perspective. Focus on scalability, security, and trade-offs. Ask clarifying questions before coding."),
        Skill(name: "Copywriter", icon: "text.quote", prompt: "You are a creative Copywriter. Write punchy, engaging, and brand-aligned text. Avoid jargon. Use active voice and strong verbs."),
        Skill(name: "Data Analyst", icon: "chart.bar.fill", prompt: "You are a Data Analyst. Interpret data with logic and precision. Look for patterns, anomalies, and actionable insights. Output clean markdown tables."),
        Skill(name: "Troubleshooter", icon: "stethoscope", prompt: "You are a Debugging Expert. Analyze errors methodically. Propose the most likely cause first, then edge cases. Provide copy-paste fixes.")
    ]
}
#endif
