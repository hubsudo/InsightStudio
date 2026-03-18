import AVFoundation

struct PlayerFactory {
    static func makePlayer(urlString: String) -> AVPlayer? {
        guard let url = URL(string: urlString) else { return nil }
        return AVPlayer(url: url)
    }
}
