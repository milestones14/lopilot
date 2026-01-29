import SwiftUI

// MARK: Views
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
    
    func cursor(_ type: NSCursor) -> some View {
        self.modifier(HandCursorModifier(pointerType: type))
    }
}

// MARK: Data
class SidebarVisibility: ObservableObject {
    @Published var isSidebarVisible: Bool = true
}

enum SizedVerticalOrder {
    case largeToSmall
    case smallToLarge
}

struct PromptSuggestion: Identifiable, Equatable {
    let id = UUID()
    
    let content: String
}

struct ModelPullProgress {
    var stageMessages: [String] = []
    var digests: [String: Float] = [:]
    var isFinished: Bool = false
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

