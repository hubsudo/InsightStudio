import Foundation

@MainActor
final class HomeViewModel {
    private let repository: VideoSourceRepository
    private(set) var videos: [VideoSummary] = []

    init(repository: VideoSourceRepository) {
        self.repository = repository
    }

    func loadVideos(keyword: String = AppEnvironment.defaultSearchKeyword) async throws {
        videos = try await repository.fetchVideos(keyword: keyword)
    }
}
