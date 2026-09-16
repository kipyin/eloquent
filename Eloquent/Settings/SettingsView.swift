import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        presentAsKey(window)
        LoginItemController.shared.refresh()
        AccessibilityPermission.shared.refresh()
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(rootView: SettingsView())
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.title = "Eloquent Settings"
        window.setContentSize(NSSize(width: 560, height: 740))
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        return window
    }

    private func presentAsKey(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}

private final class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var loginItem = LoginItemController.shared
    @ObservedObject private var accessibility = AccessibilityPermission.shared

    var body: some View {
        Form {
            Section("OpenAI TTS") {
                TextField("Engine", text: $settings.engine)
                    .textFieldStyle(.roundedBorder)
                TextField("Endpoint", text: $settings.endpoint, prompt: Text("https://api.openai.com/v1"))
                    .textFieldStyle(.roundedBorder)
                SecureField("API key", text: $settings.apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Configure Endpoint and API key for your OpenAI-compatible provider. Endpoint is the `/v1` base URL. Speak fails until Endpoint is set. Never commit API keys.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Model", text: $settings.model)
                    .textFieldStyle(.roundedBorder)
                TextField("Voice", text: $settings.voice)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text("Speed")
                    Slider(
                        value: $settings.speed,
                        in: AppSettings.Defaults.minimumSpeed...AppSettings.Defaults.maximumSpeed,
                        step: 0.1
                    )
                    Text(speedLabel)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                Text("Clamped to 0.7–1.5.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Playback") {
                Picker("Paragraph split", selection: $settings.paragraphSplit) {
                    ForEach(ParagraphSplitMode.allCases) { mode in
                        Text(mode.menuTitle).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                Text(settings.paragraphSplit.helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Hotkey") {
                LabeledContent("Speak clipboard", value: "⌥⎋  Option+Escape")
                LabeledContent("Accessibility") {
                    Text(accessibility.isTrusted ? "Granted" : "Not granted")
                        .foregroundStyle(accessibility.isTrusted ? Color.secondary : Color.orange)
                }
                if !accessibility.isTrusted {
                    Text("Grant Accessibility so Option+Escape works in every app. After enabling Eloquent, quit from the menu bar and reopen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Grant Accessibility…") {
                        accessibility.prompt()
                    }
                }
                Text("The client never sends a language field. Providers may apply their own heuristics. ja and auto are never sent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Open at Login", isOn: openAtLoginBinding)
                Text("Optional. Off by default. Uses macOS Login Items (`SMAppService`).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if loginItem.needsApproval {
                    Text("macOS needs approval. System Settings → General → Login Items & Extensions, then enable Eloquent.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let message = loginItem.lastError {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Reset Defaults") {
                    settings.resetToDefaults()
                    loginItem.setEnabled(false)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 560)
        .padding(.bottom, 8)
        .onAppear {
            loginItem.refresh()
            accessibility.refresh()
        }
    }

    private var speedLabel: String {
        String(format: "%.1f×", settings.speed)
    }

    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }
        )
    }
}
