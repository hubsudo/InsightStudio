import Foundation

final class YouTubeAPIService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchVideos(keyword: String) async throws -> [VideoSummary] {
        guard var components = URLComponents(string: AppEnvironment.youtubeBaseURL + "/search") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "maxResults", value: "5"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "key", value: AppEnvironment.youtubeAPIKey)
        ]

        guard let url = components.url else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
        return response.items.compactMap {
            guard let videoId = $0.id.videoId else { return nil }
            return VideoSummary(
                videoId: videoId,
                title: $0.snippet.title,
                description: $0.snippet.description,
                thumbnailURL: $0.snippet.thumbnails.medium.url,
                channelTitle: $0.snippet.channelTitle
            )
        }
    }
}

private struct YouTubeSearchResponse: Decodable {
    let items: [YouTubeSearchItem]
}

private struct YouTubeSearchItem: Decodable {
    let id: YouTubeVideoID
    let snippet: YouTubeSnippet
}

private struct YouTubeVideoID: Decodable {
    let videoId: String?
}

private struct YouTubeSnippet: Decodable {
    let title: String
    let description: String
    let channelTitle: String
    let thumbnails: YouTubeThumbnails
}

private struct YouTubeThumbnails: Decodable {
    let medium: YouTubeThumbnail
}

private struct YouTubeThumbnail: Decodable {
    let url: String
}
