import Foundation

protocol SelectionReading: Sendable {
    func selectedText() -> String?
}
