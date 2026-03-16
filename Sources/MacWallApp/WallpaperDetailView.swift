import SwiftUI

struct WallpaperDetailView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var renderer: DesktopRendererService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let entry = model.selectedEntry {
                    WallpaperOverviewSection(model: model, entry: entry)
                    DesktopRendererSection(model: model, renderer: renderer)
                    DisplayAssignmentsSection(model: model)
                    LockScreenSection(model: model)
                    PlaybackControlsSection(model: model)
                } else {
                    ContentUnavailableView(
                        "No Wallpaper Selected",
                        systemImage: "photo.on.rectangle.angled"
                    )
                }
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(model.selectedWallpaper?.title ?? "MacWall")
    }
}
