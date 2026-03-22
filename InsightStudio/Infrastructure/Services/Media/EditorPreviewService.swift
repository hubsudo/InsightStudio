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
    let playerLayer = AVPlayerLayer()
    var isPlaying: Bool { player.rate > 0 }
    var onPlaybackTimeChange: ((Double) -> Void)?
    var onPlaybackStateChange: ((Bool) -> Void)?

    private let player = AVPlayer()
    private var lastDraftSignature: String?
    private var currentClipID: UUID?
    private var currentClipStart: Double = 0
    private var currentClipDuration: Double = 0
    private var latestDraft: EditorDraft?
    private var desiredPlayback = false
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init() {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        player.automaticallyWaitsToMinimizeStalling = false

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, self.player.rate > 0 else { return }
            let timelineTime = self.currentClipStart + max(0, time.seconds)
            self.onPlaybackTimeChange?(timelineTime)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.handlePlaybackEnd()
            }
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func updatePreview(draft: EditorDraft, at timelineSeconds: Double, shouldPlay: Bool) async throws {
        latestDraft = draft
        desiredPlayback = shouldPlay

        guard !draft.clips.isEmpty else {
            await clearPlayer()
            return
        }

        let clampedTimelineSeconds = min(max(0, timelineSeconds), draft.totalDuration)
        let segment = resolveSegment(in: draft, at: clampedTimelineSeconds)
        let signature = Self.signature(for: draft)
        let shouldReplaceItem = signature != lastDraftSignature || currentClipID != segment.clip.id

        if shouldReplaceItem {
            let item = try buildPlayerItem(for: segment.clip)
            currentClipID = segment.clip.id
            currentClipStart = segment.startTime
            currentClipDuration = segment.clip.duration
            lastDraftSignature = signature

            await MainActor.run {
                self.player.pause()
                self.player.replaceCurrentItem(with: item)
            }

            try await waitUntilReadyToPlay(item)
        } else {
            currentClipStart = segment.startTime
            currentClipDuration = segment.clip.duration
        }

        let clipSeconds = min(max(clampedTimelineSeconds - segment.startTime, 0), segment.clip.duration)
        try await seekPlayer(to: CMTime(seconds: clipSeconds, preferredTimescale: 600))

        await MainActor.run {
            if shouldPlay {
                self.player.playImmediately(atRate: 1.0)
            } else {
                self.player.pause()
            }
            self.onPlaybackStateChange?(shouldPlay)
        }
    }

    @MainActor
    private func clearPlayer() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentClipID = nil
        currentClipStart = 0
        currentClipDuration = 0
        lastDraftSignature = nil
        desiredPlayback = false
        onPlaybackStateChange?(false)
        onPlaybackTimeChange?(0)
    }

    private func handlePlaybackEnd() async {
        guard desiredPlayback, let draft = latestDraft else {
            await MainActor.run {
                self.player.pause()
                self.onPlaybackStateChange?(false)
            }
            return
        }

        let nextTimelineTime = currentClipStart + currentClipDuration
        guard nextTimelineTime < draft.totalDuration - 0.001 else {
            desiredPlayback = false
            await MainActor.run {
                self.player.pause()
                self.onPlaybackTimeChange?(draft.totalDuration)
                self.onPlaybackStateChange?(false)
            }
            return
        }

        try? await updatePreview(draft: draft, at: nextTimelineTime, shouldPlay: true)
    }

    private func buildPlayerItem(for clip: TimelineClip) throws -> AVPlayerItem {
        guard let url = URL(string: clip.sourceURLString) else {
            throw NSError(
                domain: "EditorPreview",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无效的视频地址"]
            )
        }
        return AVPlayerItem(url: url)
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
                self.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
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

    private func resolveSegment(in draft: EditorDraft, at timelineSeconds: Double) -> (clip: TimelineClip, startTime: Double) {
        var cursor = 0.0
        for clip in draft.clips {
            let end = cursor + clip.duration
            if timelineSeconds < end || clip.id == draft.clips.last?.id {
                return (clip, cursor)
            }
            cursor = end
        }
        return (draft.clips[0], 0)
    }

    private static func signature(for draft: EditorDraft) -> String {
        draft.clips
            .map { "\($0.id.uuidString)|\($0.sourceURLString)|\($0.duration)" }
            .joined(separator: "||")
    }
}
