import Foundation

protocol StreamPlaybackService {
    func resolvePlayback(videoId: String) async throws -> StreamPlaybackInfo
}

final class DefaultStreamPlaybackService: StreamPlaybackService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func resolvePlayback(videoId: String) async throws -> StreamPlaybackInfo {
        guard let url = URL(string: AppEnvironment.backendBaseURL + "/api/v1/streams/\(videoId)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(StreamPlaybackInfo.self, from: data)
    }
}
