import SwiftUI

// MARK: Views
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

// MARK: Data
struct MarkdownSegment {
    let content: String
    let isCode: Bool
    var language: String = ""
}

