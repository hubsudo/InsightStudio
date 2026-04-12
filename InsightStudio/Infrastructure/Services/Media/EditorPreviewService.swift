import AVFoundation
import Foundation

protocol EditorPreviewService: AnyObject {
    var playerLayer: AVPlayerLayer { get }
    var isPlaying: Bool { get }
    var onPlaybackTimeChange: ((Double) -> Void)? { get set }
    var onPlaybackStateChange: ((Bool) -> Void)? { get set }
    func updatePreview(draft: EditorDraft, at timelineSeconds: Double, shouldPlay: Bool) async throws
}

final class DefaultEditorPreviewService: EditorPreviewService {
    private let viewModel: ClipPlayerViewModel
    private let compositionBuilder: TimelineCompositionBuilder

    private var currentCompositionSignature: String?
    private var currentTimelineSeconds: Double = 0
    private var latestDraft: EditorDraft?
    private var playbackTimeChangeHandler: ((Double) -> Void)?
    private var playbackStateChangeHandler: ((Bool) -> Void)?
    
    init(
        viewModel: ClipPlayerViewModel,
        compositionBuilder: TimelineCompositionBuilder
    ) {
        self.viewModel = viewModel
        self.compositionBuilder = compositionBuilder

        self.viewModel.onPlaybackTimeChange = { [weak self] seconds in
            guard let self else { return }
            self.currentTimelineSeconds = seconds
            self.playbackTimeChangeHandler?(seconds)
        }
        self.viewModel.onPlaybackStateChange = { [weak self] isPlaying in
            self?.playbackStateChangeHandler?(isPlaying)
        }
        self.viewModel.onItemDidPlayToEnd = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handlePlaybackEnd()
            }
        }
    }
    
    var playerLayer: AVPlayerLayer {
        viewModel.playerLayer
    }
    
    var isPlaying: Bool { viewModel.player.rate > 0 }

    var onPlaybackTimeChange: ((Double) -> Void)? {
        get { playbackTimeChangeHandler }
        set { playbackTimeChangeHandler = newValue }
    }

    var onPlaybackStateChange: ((Bool) -> Void)? {
        get { playbackStateChangeHandler }
        set { playbackStateChangeHandler = newValue }
    }

    func updatePreview(draft: EditorDraft, at timelineSeconds: Double, shouldPlay: Bool) async throws {
        latestDraft = draft

        guard draft.hasVideoClips else {
            await MainActor.run {
                clearPlayer()
            }
            return
        }

        let clampedTimelineSeconds = min(max(0, timelineSeconds), draft.totalDuration)
        let compositionSignature = try compositionBuilder.compositionSignature(for: draft)
        let shouldReplaceItem = compositionSignature != currentCompositionSignature

        if shouldReplaceItem {
            let item = try await buildPlayerItem(for: draft)
            currentCompositionSignature = compositionSignature

            await MainActor.run {
                self.viewModel.replaceCurrentItem(with: item)
            }

            try await waitUntilReadyToPlay(item)
        }

        if shouldReplaceItem || shouldSeek(toTimelineSeconds: clampedTimelineSeconds) {
            try await seekPlayer(to: CMTime(seconds: clampedTimelineSeconds, preferredTimescale: 600))
            currentTimelineSeconds = clampedTimelineSeconds
        } else {
            currentTimelineSeconds = currentPlayerTimeSeconds()
        }

        await MainActor.run {
            if shouldPlay {
                self.viewModel.play()
            } else {
                self.viewModel.pause()
            }
        }
    }

    @MainActor
    private func clearPlayer() {
        viewModel.clear()
        currentCompositionSignature = nil
        currentTimelineSeconds = 0
    }

    @MainActor
    private func handlePlaybackEnd() {
        viewModel.pause()
        let finalTime = latestDraft?.totalDuration ?? currentTimelineSeconds
        currentTimelineSeconds = finalTime
        playbackTimeChangeHandler?(finalTime)
    }

    private func buildPlayerItem(for draft: EditorDraft) async throws -> AVPlayerItem {
        let composition = try await compositionBuilder.buildComposition(for: draft)
        return AVPlayerItem(asset: composition)
    }

    private func waitUntilReadyToPlay(_ item: AVPlayerItem) async throws {
        if item.status == .readyToPlay {
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            var observation: NSKeyValueObservation?
            observation = item.observe(\.status, options: [.initial, .new]) { item, _ in
                switch item.status {
                case .readyToPlay:
                    observation?.invalidate()
                    continuation.resume()
                case .failed:
                    observation?.invalidate()
                    continuation.resume(throwing: item.error ?? NSError(
                        domain: "EditorPreview",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "AVPlayerItem 准备失败"]
                    ))
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func seekPlayer(to time: CMTime) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                self.viewModel.seek(to: time) { finished in
                    if finished {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "EditorPreview",
                            code: -3,
                            userInfo: [NSLocalizedDescriptionKey: "预览 seek 失败"]
                        ))
                    }
                }
            }
        }
    }

    private func shouldSeek(toTimelineSeconds targetTimelineSeconds: Double) -> Bool {
        let currentSeconds = currentPlayerTimeSeconds()
        guard currentSeconds.isFinite else { return true }
        return abs(currentSeconds - targetTimelineSeconds) > 0.05
    }

    private func currentPlayerTimeSeconds() -> Double {
        let seconds = viewModel.player.currentTime().seconds
        if seconds.isFinite {
            return max(seconds, 0)
        }
        return currentTimelineSeconds
    }
}
