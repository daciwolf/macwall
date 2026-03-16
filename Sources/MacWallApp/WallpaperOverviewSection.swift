import SwiftUI

struct WallpaperOverviewSection: View {
    @ObservedObject var model: AppModel
    let entry: WallpaperLibraryEntry

    var body: some View {
        GroupBox("Preview") {
            VStack(alignment: .leading, spacing: 10) {
                WallpaperPreviewCard(entry: entry, settings: model.previewVideoSettings)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(entry.manifest.title)
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        CompactBadge(
                            entry.source == .imported ? "Imported" : "Built-in",
                            tint: entry.source == .imported ? .blue : .secondary
                        )
                    }

                    Text(entry.manifest.summary)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    ViewThatFits(in: .vertical) {
                        HStack(spacing: 8) {
                            CompactBadge(entry.manifest.category, tint: .secondary)
                            CompactBadge(entry.manifest.creator.displayName, tint: .secondary)
                            CompactBadge("\(entry.manifest.video.width)x\(entry.manifest.video.height)", tint: .secondary)
                            CompactBadge("\(entry.manifest.video.container.rawValue.uppercased()) • \(entry.manifest.video.codec.rawValue.uppercased())", tint: .secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                CompactBadge(entry.manifest.category, tint: .secondary)
                                CompactBadge(entry.manifest.creator.displayName, tint: .secondary)
                            }

                            HStack(spacing: 8) {
                                CompactBadge("\(entry.manifest.video.width)x\(entry.manifest.video.height)", tint: .secondary)
                                CompactBadge("\(entry.manifest.video.container.rawValue.uppercased()) • \(entry.manifest.video.codec.rawValue.uppercased())", tint: .secondary)
                            }
                        }
                    }

                    if !entry.manifest.tags.isEmpty {
                        Text(entry.manifest.tags.joined(separator: " • "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if model.packageIssues.isEmpty {
                    Label("Validated", systemImage: "checkmark.shield")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.green)
                } else {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(model.packageIssues.map(\.label), id: \.self) { issue in
                                Text(issue)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        Label("\(model.packageIssues.count) issue(s)", systemImage: "exclamationmark.triangle")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WallpaperPreviewCard: View {
    let entry: WallpaperLibraryEntry
    let settings: VideoPlaybackSettings

    var body: some View {
        if let videoURL = entry.videoURL {
            LoopingVideoView(
                url: videoURL,
                settings: settings,
                playbackMode: .playingFullQuality
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12))
            )
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.orange.opacity(0.8), .cyan.opacity(0.7), .black.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 180)
                .overlay(alignment: .bottomLeading) {
                    Text("Import a video for live preview.")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(20)
                }
        }
    }
}

private struct CompactBadge: View {
    let text: String
    let tint: Color

    init(_ text: String, tint: Color) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}
