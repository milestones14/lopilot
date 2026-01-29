import SwiftUI
import Foundation

// MARK: — Message, ChatSession, ChatHistory, UserPreferences, SidebarVisibility

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

class UserPreferences {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastSelectedModel = "lastSelectedModel"
        static let isDarkModeEnabled = "isDarkModeEnabled"
        static let fontSize = "fontSize"
    }

    func saveLastSelectedModel(_ model: String) {
        defaults.set(model, forKey: Keys.lastSelectedModel)
    }

    func getLastSelectedModel() -> String? {
        return defaults.string(forKey: Keys.lastSelectedModel)
    }

    func setDarkMode(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.isDarkModeEnabled)
    }

    func isDarkModeEnabled() -> Bool {
        return defaults.bool(forKey: Keys.isDarkModeEnabled)
    }

    func saveFontSize(_ size: Float) {
        defaults.set(size, forKey: Keys.fontSize)
    }

    func getFontSize() -> Float {
        return defaults.float(forKey: Keys.fontSize)
    }
}

class SidebarVisibility: ObservableObject {
    @Published var isSidebarVisible: Bool = true
}

struct promptSuggestion: Identifiable, Equatable {
    let id = UUID()
    
    let content: String
}

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

struct HoverScaleModifier: ViewModifier {
    @State private var isHovered = false
    var pointer: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                
                if pointer {
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
    }
}
extension View {
    func hoverScale(usePointer: Bool = false) -> some View {
        self.modifier(HoverScaleModifier(pointer: usePointer))
    }
}

struct HandCursorModifier: ViewModifier {
    let pointerType: NSCursor
    
    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside {
                    pointerType.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
extension View {
    func cursor(_ type: NSCursor) -> some View {
        self.modifier(HandCursorModifier(pointerType: type))
    }
}

extension Sequence {
    func sortedByVisualWidth(
        _ keyPath: KeyPath<Element, String>,
        order: SizedVerticalOrder,
        font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    ) -> [Element] {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        
        // 1. Map to a tuple: (originalElement, calculatedWidth)
        // This ensures we only measure each string ONCE.
        return self.map { element in
            let width = (element[keyPath: keyPath] as NSString).size(withAttributes: attributes).width
            return (element, width)
        }
        // 2. Sort based on the pre-calculated width
        .sorted { a, b in
            switch order {
            case .smallToLarge: return a.1 < b.1
            case .largeToSmall: return a.1 > b.1
            }
        }
        // 3. Map back to just the original elements
        .map { $0.0 }
    }
}

enum SizedVerticalOrder {
    case largeToSmall
    case smallToLarge
}
