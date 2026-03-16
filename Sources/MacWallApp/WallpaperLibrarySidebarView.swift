import SwiftUI

struct WallpaperLibrarySidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        List(selection: $model.selectedWallpaperID) {
            ForEach(model.wallpapers) { wallpaper in
                VStack(alignment: .leading, spacing: 4) {
                    Text(wallpaper.title)
                        .font(.headline.weight(.medium))
                    Text(wallpaper.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .tag(Optional(wallpaper.id))
                .padding(.vertical, 2)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationTitle("Wallpapers")
    }
}
