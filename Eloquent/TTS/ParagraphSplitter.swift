import Foundation

enum ParagraphSplitMode: String, CaseIterable, Identifiable, Sendable {
    case blankLinesOnly = "blankLinesOnly"
    case everyNewline = "everyNewline"
    case blankLinesThenNewlines = "blankLinesThenNewlines"
    case sentences = "sentences"

    static let `default` = ParagraphSplitMode.blankLinesThenNewlines

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .blankLinesOnly:
            return "Blank lines only"
        case .everyNewline:
            return "Every newline"
        case .blankLinesThenNewlines:
            return "Blank lines, else every newline"
        case .sentences:
            return "Sentences"
        }
    }

    var helpText: String {
        switch self {
        case .blankLinesOnly:
            return "Split only on double newlines. Single line breaks stay in the same paragraph."
        case .everyNewline:
            return "Each newline starts a new paragraph."
        case .blankLinesThenNewlines:
            return "Use blank lines when the clipboard has them; otherwise split on every newline."
        case .sentences:
            return "Split on sentence endings (. ! ? 。 ！ ？). Prev/next moves one sentence at a time."
        }
    }
}

enum ParagraphSplitter {
    static func split(_ text: String, mode: ParagraphSplitMode) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return []
        }

        switch mode {
        case .blankLinesOnly:
            return nonempty(splitOnBlankLines(normalized), fallback: normalized)
        case .everyNewline:
            return nonempty(splitOnNewlines(normalized), fallback: normalized)
        case .blankLinesThenNewlines:
            let byBlank = splitOnBlankLines(normalized)
            if byBlank.count > 1 {
                return byBlank
            }
            return nonempty(splitOnNewlines(normalized), fallback: normalized)
        case .sentences:
            return nonempty(splitOnSentences(normalized), fallback: normalized)
        }
    }

    private static func splitOnBlankLines(_ text: String) -> [String] {
        text.split(separator: /\n[ \t]*\n+/, omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func splitOnNewlines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func splitOnSentences(_ text: String) -> [String] {
        let terminators: Set<Character> = [".", "!", "?", "。", "！", "？", "…", "．"]
        var sentences: [String] = []
        var current = ""
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            current.append(character)

            if terminators.contains(character) {
                var cursor = index + 1
                while cursor < characters.count, isTrailingQuote(characters[cursor]) {
                    current.append(characters[cursor])
                    cursor += 1
                }

                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""

                index = cursor
                while index < characters.count, characters[index].isWhitespace {
                    index += 1
                }
                continue
            }

            index += 1
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            sentences.append(tail)
        }
        return sentences
    }

    private static func isTrailingQuote(_ character: Character) -> Bool {
        switch character {
        case "\"", "'", "”", "’", "」", "』", "）", ")":
            return true
        default:
            return false
        }
    }

    private static func nonempty(_ parts: [String], fallback: String) -> [String] {
        parts.isEmpty ? [fallback] : parts
    }
}
