import Foundation

struct VideoSummary: Decodable, Hashable {
    let videoId: String
    let title: String
    let description: String
    let thumbnailURL: String
    let channelTitle: String

    init(videoId: String, title: String, description: String, thumbnailURL: String, channelTitle: String) {
        self.videoId = videoId
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.channelTitle = channelTitle
    }
}
