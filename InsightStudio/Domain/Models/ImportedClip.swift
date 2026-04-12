import Foundation

enum ImportedClipDownloadState: String, Codable, Hashable {
    case idle
    case downloading
    case ready
    case failed
    // TODO: 标记“删除”状态
    case deleted
}

enum ImportedClipSourceKind: String, Codable, Hashable, Sendable {
    case remoteImport
    case editedResult
    case recoveredLocal
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
    var sourceKind: ImportedClipSourceKind
    var lastErrorMessage: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceID
        case videoId
        case title
        case thumbnailURL
        case remoteStreamURL
        case localFileURL
        case durationSeconds
        case importedAt
        case selectedStartSeconds
        case selectedEndSeconds
        case downloadState
        case downloadProgress
        case sourceKind
        case lastErrorMessage
    }

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
        sourceKind: ImportedClipSourceKind = .remoteImport,
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
        self.sourceKind = sourceKind
        self.lastErrorMessage = lastErrorMessage
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceID = try container.decode(String.self, forKey: .sourceID)
        videoId = try container.decode(String.self, forKey: .videoId)
        title = try container.decode(String.self, forKey: .title)
        thumbnailURL = try container.decode(String.self, forKey: .thumbnailURL)
        remoteStreamURL = try container.decode(String.self, forKey: .remoteStreamURL)
        localFileURL = try container.decodeIfPresent(URL.self, forKey: .localFileURL)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        importedAt = try container.decode(Date.self, forKey: .importedAt)
        selectedStartSeconds = try container.decode(Double.self, forKey: .selectedStartSeconds)
        selectedEndSeconds = try container.decode(Double.self, forKey: .selectedEndSeconds)
        downloadState = try container.decode(ImportedClipDownloadState.self, forKey: .downloadState)
        downloadProgress = try container.decode(Double.self, forKey: .downloadProgress)
        sourceKind = try container.decodeIfPresent(ImportedClipSourceKind.self, forKey: .sourceKind) ?? .remoteImport
        lastErrorMessage = try container.decodeIfPresent(String.self, forKey: .lastErrorMessage)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sourceID, forKey: .sourceID)
        try container.encode(videoId, forKey: .videoId)
        try container.encode(title, forKey: .title)
        try container.encode(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(remoteStreamURL, forKey: .remoteStreamURL)
        try container.encodeIfPresent(localFileURL, forKey: .localFileURL)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(importedAt, forKey: .importedAt)
        try container.encode(selectedStartSeconds, forKey: .selectedStartSeconds)
        try container.encode(selectedEndSeconds, forKey: .selectedEndSeconds)
        try container.encode(downloadState, forKey: .downloadState)
        try container.encode(downloadProgress, forKey: .downloadProgress)
        try container.encode(sourceKind, forKey: .sourceKind)
        try container.encodeIfPresent(lastErrorMessage, forKey: .lastErrorMessage)
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

    var isEditedResult: Bool {
        sourceKind == .editedResult
    }
}
