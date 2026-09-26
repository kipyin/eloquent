import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var speech: SpeechController
    @ObservedObject private var settings: AppSettings

    init(speech: SpeechController) {
        self.speech = speech
        self.settings = .shared
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(speech.progressLabel)
                    .font(.headline)
                Spacer()
                statusBadge
            }

            HStack(spacing: 18) {
                controlButton(
                    systemName: "backward.end.fill",
                    label: "Previous paragraph",
                    enabled: speech.canGoPrevious,
                    action: { speech.previous() }
                )
                controlButton(
                    systemName: speech.isPaused ? "play.fill" : "pause.fill",
                    label: speech.isPaused ? "Resume" : "Pause",
                    enabled: speech.canTogglePause,
                    action: { speech.togglePause() }
                )
                controlButton(
                    systemName: "stop.fill",
                    label: "Stop",
                    enabled: speech.canStop,
                    action: { speech.stop() }
                )
                controlButton(
                    systemName: "forward.end.fill",
                    label: "Next paragraph",
                    enabled: speech.canGoNext,
                    action: { speech.next() }
                )
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text("Speed")
                Slider(
                    value: $settings.speed,
                    in: TTSDefaults.minimumSpeed...TTSDefaults.maximumSpeed,
                    step: 0.1
                ) { editing in
                    if !editing {
                        speech.applySpeedChange()
                    }
                }
                Text(TTSDefaults.speedLabel(for: settings.speed))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }

            preview
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: 320)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch speech.state {
        case .idle:
            EmptyView()
        case .loading:
            Text("Loading")
                .foregroundStyle(.secondary)
        case .playing:
            Text("Playing")
                .foregroundStyle(.secondary)
        case .paused:
            Text("Paused")
                .foregroundStyle(.secondary)
        case .failed:
            Text("Error")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch speech.state {
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        case .idle, .loading, .playing, .paused:
            Text(speech.currentPreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func controlButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 22)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .help(label)
        .accessibilityLabel(label)
    }
}
