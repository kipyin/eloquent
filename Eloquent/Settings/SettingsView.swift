import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let speech: SpeechController
    private var window: NSWindow?

    init(speech: SpeechController) {
        self.speech = speech
        super.init()
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        presentAsKey(window)
        LoginItemController.shared.refresh()
        AccessibilityPermission.shared.refresh()
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(rootView: SettingsView(onSpeedCommitted: { [speech] in
            speech.applySpeedChange()
        }))
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.title = "Eloquent Settings"
        window.setContentSize(NSSize(width: 560, height: 800))
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self
        return window
    }

    func windowWillClose(_ notification: Notification) {
        SpeakHotkeyController.shared.cancelRecording()
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
    var onSpeedCommitted: () -> Void
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var loginItem = LoginItemController.shared
    @ObservedObject private var accessibility = AccessibilityPermission.shared
    @ObservedObject private var speakHotkey = SpeakHotkeyController.shared

    var body: some View {
        Form {
            Section("TTS") {
                Picker("Engine", selection: $settings.engine) {
                    ForEach(Engine.allCases) { engine in
                        Text(engine.menuTitle).tag(engine)
                    }
                }
                SettingsTextField(
                    title: "Endpoint",
                    text: $settings.endpoint,
                    prompt: Text(settings.engine.officialEndpoint)
                )
                SettingsTextField(title: "API key", text: $settings.apiKey, secure: true)
                Text("Configure Endpoint and API key for the selected engine. Endpoint is the `/v1` base URL. Speak fails until Endpoint is set. Never commit API keys.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if settings.engine == .openai {
                    SettingsTextField(title: "Model", text: $settings.model)
                }
                SettingsTextField(title: "Voice", text: $settings.voice)
                HStack {
                    Text("Speed")
                    Slider(
                        value: $settings.speed,
                        in: AppSettings.Defaults.minimumSpeed...AppSettings.Defaults.maximumSpeed,
                        step: 0.1
                    ) { editing in
                        if !editing {
                            onSpeedCommitted()
                        }
                    }
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
                Picker("Speed apply", selection: $settings.speedApply) {
                    ForEach(SpeedApplyMode.allCases) { mode in
                        Text(mode.menuTitle).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                Text(settings.speedApply.helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Hotkey") {
                SpeakHotkeyRecorder(settings: settings, controller: speakHotkey)
                LabeledContent("Accessibility") {
                    Text(accessibility.isTrusted ? "Granted" : "Not granted")
                        .foregroundStyle(accessibility.isTrusted ? Color.secondary : Color.orange)
                }
                if !accessibility.isTrusted {
                    Text("Grant Accessibility so \(settings.speakHotkey.words) and selection reading work in every app. After enabling Eloquent, quit from the menu bar and reopen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Grant Accessibility…") {
                        accessibility.prompt()
                    }
                }
                Text("OpenAI requests omit a language field; providers may apply their own heuristics. Grok always sends language auto. ja is never sent.")
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
                    speakHotkey.reinstallAfterReset()
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

private struct SpeakHotkeyRecorder: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var controller: SpeakHotkeyController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Speak selection or clipboard")
                Spacer()
                Button(recorderTitle) {
                    if controller.isRecording {
                        controller.cancelRecording()
                    } else {
                        controller.beginRecording()
                    }
                }
                .help("Click, then press the new shortcut. Press Escape to cancel.")
            }
            if let error = controller.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Text("Click the shortcut, then press the new keys. The previous shortcut stays active if the new one is reserved or already used.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var recorderTitle: String {
        if controller.isRecording {
            return "Type a shortcut…"
        }
        return settings.speakHotkey.displayLabel
    }
}

// Grouped Form keeps labeled TextField text trailing. Hide the field label
// and pin NSTextField.alignment so typed values start at the leading edge.
private struct SettingsTextField: View {
    let title: String
    @Binding var text: String
    var prompt: Text?
    var secure = false

    var body: some View {
        LabeledContent(title) {
            field
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .multilineTextAlignment(.leading)
                .background(LeadingNSTextFieldAlignment())
        }
    }

    @ViewBuilder
    private var field: some View {
        if secure {
            SecureField(title, text: $text)
        } else if let prompt {
            TextField(title, text: $text, prompt: prompt)
        } else {
            TextField(title, text: $text)
        }
    }
}

private struct LeadingNSTextFieldAlignment: NSViewRepresentable {
    func makeNSView(context: Context) -> AlignmentProbe {
        AlignmentProbe()
    }

    func updateNSView(_ nsView: AlignmentProbe, context: Context) {
        nsView.apply()
    }
}

private final class AlignmentProbe: NSView {
    override var intrinsicContentSize: NSSize { .zero }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    override func layout() {
        super.layout()
        apply()
    }

    func apply() {
        DispatchQueue.main.async { [weak self] in
            self?.alignNearestTextField()
        }
    }

    private func alignNearestTextField() {
        guard let field = nearestTextField() else { return }
        if field.alignment != .left {
            field.alignment = .left
        }
        if let cell = field.cell as? NSTextFieldCell, cell.alignment != .left {
            cell.alignment = .left
        }
        if let editor = field.currentEditor() as? NSTextView, editor.alignment != .left {
            editor.alignment = .left
        }
    }

    private func nearestTextField() -> NSTextField? {
        var node: NSView? = superview
        while let current = node {
            let fields = collectTextFields(from: current)
            if fields.count == 1 {
                return fields[0]
            }
            if fields.count > 1 {
                return closestField(in: fields)
            }
            node = current.superview
        }
        return nil
    }

    private func collectTextFields(from view: NSView) -> [NSTextField] {
        if let field = view as? NSTextField {
            return [field]
        }
        return view.subviews.flatMap { collectTextFields(from: $0) }
    }

    private func closestField(in fields: [NSTextField]) -> NSTextField? {
        let origin = convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)
        return fields.min { lhs, rhs in
            let left = lhs.convert(NSPoint(x: lhs.bounds.midX, y: lhs.bounds.midY), to: nil)
            let right = rhs.convert(NSPoint(x: rhs.bounds.midX, y: rhs.bounds.midY), to: nil)
            let leftDistance = hypot(left.x - origin.x, left.y - origin.y)
            let rightDistance = hypot(right.x - origin.x, right.y - origin.y)
            return leftDistance < rightDistance
        }
    }
}
