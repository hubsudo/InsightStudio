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
        loadAll().sorted { $0.importedAt > $1.importedAt }
    }

    func save(_ clip: ImportedClip) {
        var clips = loadAll()
        clips.removeAll { $0.videoId == clip.videoId }
        clips.insert(clip, at: 0)
        persist(clips)
    }

    func update(_ clip: ImportedClip) {
        var clips = loadAll()
        if let idx = clips.firstIndex(where: { $0.id == clip.id }) {
            clips[idx] = clip
        }
        persist(clips)
    }
    
    func updateProgress(for id: UUID, progress: Double) {
        var clips = loadAll()
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].downloadProgress = progress
        clips[index].downloadState = .downloading
        persist(clips)
    }
    
    func markReady(for id: UUID, localFileURL: URL, durationSeconds: Double) {
        var clips = loadAll()
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].downloadProgress = 1.0
        clips[index].downloadState = .ready
        clips[index].localFileURL = localFileURL
        clips[index].durationSeconds = durationSeconds
        clips[index].lastErrorMessage = nil
        persist(clips)
    }
    
    func markFailed(for id: UUID, message: String) {
        var clips = loadAll()
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].downloadState = .failed
        clips[index].lastErrorMessage = message
        persist(clips)
    }
    
    func findClip(by id: UUID) -> ImportedClip? {
        loadAll().first(where: {$0.id == id})
    }
    
    private func loadAll() -> [ImportedClip] {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let clips = try? decoder.decode([ImportedClip].self, from: data)
        else { return [] }
        return clips
    }

    private func persist(_ clips: [ImportedClip]) {
        guard let data = try? encoder.encode(clips) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
