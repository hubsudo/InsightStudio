import Foundation

struct ImportedClip: Codable, Hashable {
    let id: UUID
    let sourceID: String
    let videoId: String
    let title: String
    let thumbnailURL: String
    let remoteStreamURL: String
    let localFileURL: URL // AVAsset
    let durationSeconds: Double
    let importedAt: Date
    var selectedStartSeconds: Double
    var selectedEndSeconds: Double

    init(
        id: UUID = UUID(),
        sourceID: String,
        videoId: String,
        title: String,
        thumbnailURL: String,
        remoteStreamURL: String,
        localFileURL: URL,
        durationSeconds: Double,
        importedAt: Date = Date(),
        selectedStartSeconds: Double = 0,
        selectedEndSeconds: Double = 15
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
    }
}
