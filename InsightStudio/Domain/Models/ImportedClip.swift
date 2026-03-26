import Foundation

enum ImportedClipDownloadState: String, Codable, Hashable {
    case idle
    case downloading
    case ready
    case failed
    // TODO: 标记“删除”状态
    case deleted
}

struct ImportedClip: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let sourceID: String
    let videoId: String
    var title: String
    var thumbnailURL: String
    var remoteStreamURL: String
    var localFileURL: URL? // AVURLAsset
    
    var durationSeconds: Double
    let importedAt: Date
    var selectedStartSeconds: Double
    var selectedEndSeconds: Double
    
    var downloadState: ImportedClipDownloadState
    var downloadProgress: Double
    var lastErrorMessage: String?

    init(
        id: UUID = UUID(),
        sourceID: String,
        videoId: String,
        title: String,
        thumbnailURL: String,
        remoteStreamURL: String,
        localFileURL: URL?,
        durationSeconds: Double,
        importedAt: Date = Date(),
        selectedStartSeconds: Double,
        selectedEndSeconds: Double,
        downloadState: ImportedClipDownloadState,
        downloadProgress: Double,
        lastErrorMessage: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.videoId = videoId
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.remoteStreamURL = remoteStreamURL
        self.localFileURL = localFileURL
        self.durationSeconds = durationSeconds
        self.importedAt = importedAt
        self.selectedStartSeconds = selectedStartSeconds
        self.selectedEndSeconds = selectedEndSeconds
        self.downloadState = downloadState
        self.downloadProgress = downloadProgress
        self.lastErrorMessage = lastErrorMessage
    }
}

enum ClipPlaybackSource: Hashable {
    case localFile(URL)
    case remoteStream(URL)
}

extension ImportedClip {
    var localFileExists: Bool {
        guard let localFileURL else { return false }
        return FileManager.default.fileExists(atPath: localFileURL.path)
    }
    
    var resolvedDownloadState: ImportedClipDownloadState {
        if localFileExists { return .ready }
        return downloadState
    }
    
    var playbackSource: ClipPlaybackSource? {
        if let localFileURL, FileManager.default.fileExists(atPath: localFileURL.path) {
            return .localFile(localFileURL)
        }
        
        guard let remoteURL = URL(string: remoteStreamURL) else { return nil }
        return .remoteStream(remoteURL)
    }
}
