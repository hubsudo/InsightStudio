import Foundation

struct ImportedClip: Codable, Hashable {
    let id: UUID
    let videoId: String
    let title: String
    let thumbnailURL: String
    let remoteStreamURL: String
    let importedAt: Date
    var selectedStartSeconds: Double
    var selectedEndSeconds: Double

    init(
        id: UUID = UUID(),
        videoId: String,
        title: String,
        thumbnailURL: String,
        remoteStreamURL: String,
        importedAt: Date = Date(),
        selectedStartSeconds: Double = 0,
        selectedEndSeconds: Double = 15
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.remoteStreamURL = remoteStreamURL
        self.importedAt = importedAt
        self.selectedStartSeconds = selectedStartSeconds
        self.selectedEndSeconds = selectedEndSeconds
    }
}
