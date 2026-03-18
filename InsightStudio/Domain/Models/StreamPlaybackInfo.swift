import Foundation

struct StreamPlaybackInfo: Decodable {
    let videoId: String
    let title: String
    let streamURL: String
    let thumbnailURL: String?
    let durationSeconds: Int?
    let extractor: String?

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case title
        case streamURL = "stream_url"
        case thumbnailURL = "thumbnail_url"
        case durationSeconds = "duration_seconds"
        case extractor
    }
}
