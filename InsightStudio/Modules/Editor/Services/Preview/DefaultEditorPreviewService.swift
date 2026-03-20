import AVFoundation
import Foundation

public final class DefaultEditorPreviewService: EditorPreviewService {
    public let player: AVPlayer
    public let playerLayer: AVPlayerLayer

    private let compositionBuilder: CompositionBuilder
    private var currentDraft: TimelineDraft?
    private var lastSeekSeconds: Double = 0

    public init(compositionBuilder: CompositionBuilder) {
        self.compositionBuilder = compositionBuilder
        self.player = AVPlayer()
        self.playerLayer = AVPlayerLayer(player: player)
        self.playerLayer.videoGravity = .resizeAspect
    }

    public func updatePreview(draft: TimelineDraft, at timelineSeconds: Double) async throws {
        let shouldRebuild = currentDraft != draft
        currentDraft = draft
        lastSeekSeconds = max(0, min(timelineSeconds, draft.totalDuration))

        if shouldRebuild {
            let buildResult = try await compositionBuilder.build(from: draft)
            let item = AVPlayerItem(asset: buildResult.composition)
            item.videoComposition = buildResult.videoComposition
            await MainActor.run {
                self.player.replaceCurrentItem(with: item)
            }
        }

        let target = CMTime(seconds: lastSeekSeconds, preferredTimescale: 600)
        await MainActor.run {
            self.player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    public func play() {
        player.play()
    }

    public func pause() {
        player.pause()
    }
}
