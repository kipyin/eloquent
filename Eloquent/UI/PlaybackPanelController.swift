import AppKit
import Combine
import SwiftUI

@MainActor
final class PlaybackPanelController: NSObject, NSWindowDelegate {
    private let speech: SpeechController
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    init(speech: SpeechController) {
        self.speech = speech
        super.init()
        speech.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncVisibility()
            }
            .store(in: &cancellables)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        speech.stop()
        return false
    }

    private func syncVisibility() {
        if speech.showsFloatingPanel {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        if !panel.isVisible {
            position(panel)
        }
        panel.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let hosting = NSHostingController(rootView: ControlPanelView(speech: speech))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 120),
            styleMask: [.titled, .fullSizeContentView, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.title = "Eloquent"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self
        panel.setContentSize(NSSize(width: 340, height: 118))
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + 64
        )
        panel.setFrameOrigin(origin)
    }
}
