import AVFoundation

struct PlayerFactory {
    //TODO: 缓存实例
//    static var sharedPlayer: AVPlayer?
    static func makePlayer(urlString: String) -> AVPlayer? {
        guard let url = URL(string: urlString) else { return nil }
        return AVPlayer(url: url)
    }
    
    static func resolveURL(from importedClip: ImportedClip) -> URL? {
        switch importedClip.playbackSource {
        case .localFile(let url):
            return url
        case .remoteStream(let url):
            return url
        case .none:
            return nil
        }
    }
}
