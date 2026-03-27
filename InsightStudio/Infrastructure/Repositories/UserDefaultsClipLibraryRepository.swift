import Foundation
import AVFoundation

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
        // 去重
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
        loadAll().first(where: { $0.id == id })
    }
    
    func deleteClip(by id: UUID) {
        var clips = loadAll()
        
        // 删除磁盘文件
        if let clip = clips.first(where: { $0.id == id }),
           let localFileURL = clip.localFileURL,
           FileManager.default.fileExists(atPath: localFileURL.path) {
            try? FileManager.default.removeItem(at: localFileURL)
        }
        
        clips.removeAll { $0.id == id }
        persist(clips)
    }
    
    func deleteAllClips() {
        let clips = loadAll()
        let fm = FileManager.default
        
        // 删除磁盘文件
        for clip in clips {
            if let localFileURL = clip.localFileURL,
               fm.fileExists(atPath: localFileURL.path) {
                try? fm.removeItem(at: localFileURL)
            }
        }
        
        userDefaults.removeObject(forKey: storageKey)
    }
    
    func reconcileLocalFiles() async -> [ImportedClip] {
        var clips = loadAll()
        let fileStore = EditorImportFileStore.shared

        var didChange = false

        // 1. 修正“记录里有本地路径，但磁盘已丢失”的 clip
        for index in clips.indices {
            if reconcileStoredClipPath(&clips[index], fileStore: fileStore) {
                didChange = true
            }
        }

        // 2. 恢复 orphan 文件：磁盘有文件，但仓库无记录
        let allFiles = fileStore.allLocalFiles()
        var knownSourceIDs = Set(clips.map(\.sourceID))

        var recoveredClips: [ImportedClip] = []
        recoveredClips.reserveCapacity(allFiles.count)

        for fileURL in allFiles {
            let sourceID = fileURL
                .deletingPathExtension()
                .lastPathComponent
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard sourceID.isEmpty == false else { continue }
            guard knownSourceIDs.contains(sourceID) == false else { continue }

            let durationSeconds = await loadDurationSeconds(from: fileURL)
            let safeDuration = normalizedDuration(durationSeconds)

            let clip = ImportedClip(
                sourceID: sourceID,
                videoId: sourceID,
                title: recoveredTitle(for: fileURL),
                thumbnailURL: "",
                remoteStreamURL: "",
                localFileURL: fileURL,
                durationSeconds: safeDuration,
                selectedStartSeconds: 0,
                selectedEndSeconds: safeDuration,
                downloadState: .ready,
                downloadProgress: 1.0,
                lastErrorMessage: nil
            )

            recoveredClips.append(clip)
            knownSourceIDs.insert(sourceID)
            didChange = true
        }

        if recoveredClips.isEmpty == false {
            clips.insert(contentsOf: recoveredClips, at: 0)
        }

        clips.sort { $0.importedAt > $1.importedAt }

        if didChange {
            persist(clips)
        }

        return clips
    }
}

private extension UserDefaultsClipLibraryRepository {
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
    
    func recoveredTitle(for fileURL: URL) -> String {
        let name = fileURL.deletingPathExtension().lastPathComponent
        return name.isEmpty ? "Recovered Clip" : name
    }

    func normalizedDuration(_ durationSeconds: Double) -> Double {
        guard durationSeconds.isFinite, durationSeconds > 0 else { return 15 }
        return durationSeconds
    }

    func loadDurationSeconds(from fileURL: URL) async -> Double {
        let asset = AVURLAsset(url: fileURL)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 15
        }
    }
    
    private func reconcileStoredClipPath(
        _ clip: inout ImportedClip,
        fileStore: EditorImportFileStore
    ) -> Bool {
        let sourceID = clip.sourceID
        let fallbackURL = fileStore.localURL(for: sourceID)

        if let localURL = clip.localFileURL {
            if fileStore.fileExists(at: localURL) {
                return false
            }

            if fileStore.fileExists(for: sourceID) {
                clip.localFileURL = fallbackURL
                clip.downloadState = .ready
                clip.downloadProgress = 1.0
                clip.lastErrorMessage = nil
                return true
            }

            clip.localFileURL = nil
            clip.downloadState = .failed
            clip.downloadProgress = 0
            clip.lastErrorMessage = "本地文件已丢失"
            return true
        }
        
        if fileStore.fileExists(for: sourceID) {
            clip.localFileURL = fallbackURL
            clip.downloadState = .ready
            clip.downloadProgress = 1.0
            clip.lastErrorMessage = nil
            return true
        }

        return false
    }
}
