import Foundation

protocol VideoSourceRepository {
    func fetchVideos(keyword: String) async throws -> [VideoSummary]
}
