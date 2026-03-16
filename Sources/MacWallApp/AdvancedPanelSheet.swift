import SwiftUI

enum AdvancedPanel: String, Identifiable {
    case powerAndPlayback
    case diagnostics

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .powerAndPlayback:
            return "Power & Playback"
        case .diagnostics:
            return "Diagnostics"
        }
    }
}

struct AdvancedPanelSheet: View {
    let panel: AdvancedPanel
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch panel {
                    case .powerAndPlayback:
                        PlaybackPolicySection(model: model)
                    case .diagnostics:
                        DiagnosticsSection(model: model)
                    }
                }
                .padding(24)
            }
            .navigationTitle(panel.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}
