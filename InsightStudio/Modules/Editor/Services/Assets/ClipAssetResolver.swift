import Foundation
import AVFoundation

protocol ClipAssetResolver {
    func resolveURL(for asset: ClipAsset) async throws -> URL
    func resolveAsset(for asset: ClipAsset) async throws -> AVAsset
}

final class DefaultClipAssetResolver: ClipAssetResolver {
    private let fallbackProvider: DemoLocalAssetProvider?

    init(fallbackProvider: DemoLocalAssetProvider? = nil) {
        self.fallbackProvider = fallbackProvider
    }

    func resolveURL(for asset: ClipAsset) async throws -> URL {
        switch asset {
        case .localFile(let url):
            return url
        }
    }

    func resolveAsset(for asset: ClipAsset) async throws -> AVAsset {
        let url = try await resolveURL(for: asset)
        return AVURLAsset(url: url)
    }
}
