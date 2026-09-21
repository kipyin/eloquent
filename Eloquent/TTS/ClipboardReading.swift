import Foundation

protocol ClipboardReading: Sendable {
    func string() -> String?
}
