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
            window.setContentSize(NSSize(width: 560, height: 680))
            window.center()
            window.isReleasedWhenClosed = false
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        LoginItemController.shared.refresh()
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var loginItem = LoginItemController.shared

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
                Picker("Paragraph split", selection: $settings.paragraphSplit) {
                    ForEach(ParagraphSplitMode.allCases) { mode in
                        Text(mode.menuTitle).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                Text(settings.paragraphSplit.helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Speak clipboard", value: "⌥⎋  Option+Escape")
                Text("Language is omitted on purpose so the local proxy’s zh/en heuristic applies. ja and auto are never sent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Open at Login", isOn: openAtLoginBinding)
                Text("Optional. Off by default. Uses macOS Login Items (`SMAppService`).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if loginItem.needsApproval {
                    Text("macOS needs approval. System Settings → General → Login Items & Extensions, then enable Clipboard TTS.")
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
