import AVFoundation

struct PlayerFactory {
    //TODO: 缓存实例
//    static var sharedPlayer: AVPlayer?
    static func makePlayer(urlString: String) -> AVPlayer? {
        guard let url = URL(string: urlString) else { return nil }
        return AVPlayer(url: url)
    }
    
    static func makePlayerItem(from clip: ImportedClip) -> AVPlayerItem? {
        guard let source = clip.playbackSource else { return nil }

        switch source {
        case .localFile(let url):
            let asset = AVURLAsset(url: url)
            return AVPlayerItem(asset: asset)

        case .remoteStream(let url):
            let asset = AVURLAsset(url: url)
            return AVPlayerItem(asset: asset)
        }
    }
}
