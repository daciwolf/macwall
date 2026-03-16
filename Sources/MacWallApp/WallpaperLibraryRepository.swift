struct WallpaperLibraryRepository {
    private let store: WallpaperLibraryStore

    init(store: WallpaperLibraryStore) {
        self.store = store
    }

    func loadLibraryEntries() -> [WallpaperLibraryEntry] {
        DemoWallpaperLibrary.entries + ((try? store.loadImportedEntries()) ?? [])
    }

    func saveImportedEntries(from libraryEntries: [WallpaperLibraryEntry]) throws {
        try store.saveImportedEntries(
            libraryEntries.filter { $0.source == .imported }
        )
    }
}
