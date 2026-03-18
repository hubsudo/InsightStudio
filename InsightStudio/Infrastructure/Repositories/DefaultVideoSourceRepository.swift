import Foundation

final class DefaultVideoSourceRepository: VideoSourceRepository {
    private let apiService: YouTubeAPIService

    init(apiService: YouTubeAPIService) {
        self.apiService = apiService
    }

    func fetchVideos(keyword: String) async throws -> [VideoSummary] {
        try await apiService.searchVideos(keyword: keyword)
    }
}
