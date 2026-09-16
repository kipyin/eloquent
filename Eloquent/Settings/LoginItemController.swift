import Combine
import Foundation
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    static let shared = LoginItemController()

    @Published private(set) var isEnabled = false
    @Published private(set) var needsApproval = false
    @Published private(set) var lastError: String?

    private init() {
        refresh()
    }

    func refresh() {
        apply(status: SMAppService.mainApp.status)
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                switch SMAppService.mainApp.status {
                case .notRegistered, .notFound:
                    break
                case .enabled, .requiresApproval:
                    try SMAppService.mainApp.unregister()
                @unknown default:
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    private func apply(status: SMAppService.Status) {
        switch status {
        case .enabled:
            isEnabled = true
            needsApproval = false
        case .requiresApproval:
            isEnabled = true
            needsApproval = true
        case .notRegistered, .notFound:
            isEnabled = false
            needsApproval = false
        @unknown default:
            isEnabled = false
            needsApproval = false
        }
    }
}
