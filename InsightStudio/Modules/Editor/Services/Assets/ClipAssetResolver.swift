import AVFoundation
import Foundation

public protocol ClipAssetResolver {
    func resolveURL(for asset: ClipAsset) async throws -> URL
    func resolveAsset(for asset: ClipAsset) async throws -> AVAsset
}

public enum ClipAssetResolverError: Error {
    case remoteAssetNotDownloaded
}

public final class DefaultClipAssetResolver: ClipAssetResolver {
    public init() {}

    public func resolveURL(for asset: ClipAsset) async throws -> URL {
        switch asset {
        case .localFile(let url):
            return url
        case .remoteVideo:
            throw ClipAssetResolverError.remoteAssetNotDownloaded
        }
    }

    public func resolveAsset(for asset: ClipAsset) async throws -> AVAsset {
        let url = try await resolveURL(for: asset)
        return AVURLAsset(url: url)
    }
}
