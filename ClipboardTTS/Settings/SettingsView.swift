import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.title = "Clipboard TTS Settings"
            window.setContentSize(NSSize(width: 560, height: 500))
            window.center()
            window.isReleasedWhenClosed = false
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("OpenAI TTS") {
                TextField("Engine", text: $settings.engine)
                    .textFieldStyle(.roundedBorder)
                TextField("Endpoint", text: $settings.endpoint)
                    .textFieldStyle(.roundedBorder)
                SecureField("API key", text: $settings.apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Leave empty when using the local proxy. The proxy holds the upstream key. Never paste a real xAI key into the repo.")
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
                Text("Clamped to 0.7–1.5 to match the proxy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Playback") {
                LabeledContent("Speak clipboard", value: "⌥⎋  Option+Escape")
                Text("Language is omitted on purpose so the local proxy’s zh/en heuristic applies. ja and auto are never sent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset Defaults") {
                    settings.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 460)
        .padding(.bottom, 8)
    }

    private var speedLabel: String {
        String(format: "%.1f×", settings.speed)
    }
}
