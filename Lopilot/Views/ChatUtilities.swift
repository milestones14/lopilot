import SwiftUI

// MARK: Views
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

// MARK: Data
struct AttachedFile: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let content: String
    
    init(id: UUID = UUID(), name: String, content: String) {
        self.id = id
        self.name = name
        self.content = content
    }
}

struct Message: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
    let id: UUID
    let role: Role
    let text: String
    let modelUserFriendly: String
    var isLoading: Bool = false
    var attachments: [AttachedFile]? = nil // New property for attachments

    init(id: UUID = UUID(), role: Role, text: String, modelUserFriendly: String, isLoading: Bool, attachments: [AttachedFile]? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.modelUserFriendly = modelUserFriendly
        self.isLoading = isLoading
        self.attachments = attachments
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var timestamp: Date
    var messages: [Message]

    init(id: UUID = UUID(), name: String, timestamp: Date = Date(), messages: [Message] = []) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.messages = messages
    }

    static func == (lhs: ChatSession, rhs: ChatSession) -> Bool {
        return lhs.id == rhs.id
    }
}

@MainActor
class ChatHistory: ObservableObject {
    @Published var sessions: [ChatSession] = []
    private let defaults = UserDefaults.standard
    private let historyKey = "chatHistory"

    init() {
        loadSessions()
    }

    func saveSession(_ session: ChatSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
            // Only sort when a NEW session is added, not on every message update
            sessions.sort(by: { $0.timestamp > $1.timestamp })
        }
        saveToUserDefaults()
    }

    func loadSessions() {
        if let data = defaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([ChatSession].self, from: data) {
            sessions = decoded.sorted(by: { $0.timestamp > $1.timestamp })
        }
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        saveToUserDefaults()
    }
    
    func clearAllSessions() {
        self.sessions = []
        saveToUserDefaults()
    }

    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            defaults.set(encoded, forKey: historyKey)
        }
    }
}
