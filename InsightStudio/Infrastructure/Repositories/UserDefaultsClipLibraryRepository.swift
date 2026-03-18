import Foundation

final class UserDefaultsClipLibraryRepository: ClipLibraryRepository {
    private let storageKey: String
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(storageKey: String, userDefaults: UserDefaults = .standard) {
        self.storageKey = storageKey
        self.userDefaults = userDefaults
    }

    func fetchRecentImports() -> [ImportedClip] {
        guard let data = userDefaults.data(forKey: storageKey),
              let clips = try? decoder.decode([ImportedClip].self, from: data)
        else { return [] }
        return clips.sorted { $0.importedAt > $1.importedAt }
    }

    func save(_ clip: ImportedClip) {
        var clips = fetchRecentImports()
        clips.removeAll { $0.videoId == clip.videoId }
        clips.insert(clip, at: 0)
        persist(clips)
    }

    func update(_ clip: ImportedClip) {
        var clips = fetchRecentImports()
        if let idx = clips.firstIndex(where: { $0.id == clip.id }) {
            clips[idx] = clip
        }
        persist(clips)
    }

    private func persist(_ clips: [ImportedClip]) {
        guard let data = try? encoder.encode(clips) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
