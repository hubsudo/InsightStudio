import AVFoundation
import Foundation

public protocol EditorPreviewService: AnyObject {
    var player: AVPlayer { get }
    var playerLayer: AVPlayerLayer { get }

    func updatePreview(draft: TimelineDraft, at timelineSeconds: Double) async throws
    func play()
    func pause()
}
