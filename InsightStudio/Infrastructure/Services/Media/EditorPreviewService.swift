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
    private let clipRepository: any ClipLibraryRepository
    
    private var lastDraftSignature: String?
    private var currentClipID: UUID?
    private var currentClipStart: Double = 0
    private var currentClipSourceStart: Double = 0
    private var currentClipDuration: Double = 0
    private var latestDraft: EditorDraft?
    private var desiredPlayback = false
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var isHandlingPlaybackEnd = false
    
    init(
        viewModel: ClipPlayerViewModel,
        clipRepository: ClipLibraryRepository,
    ) {
        self.viewModel = viewModel
        self.clipRepository = clipRepository
        
        timeObserver = viewModel.player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, self.viewModel.player.rate > 0 else { return }
            let clipSeconds = max(0, time.seconds - self.currentClipSourceStart)
            let timelineTime = self.currentClipStart + min(clipSeconds, self.currentClipDuration)
            self.onPlaybackTimeChange?(timelineTime)
            if clipSeconds >= self.currentClipDuration - 0.01 {
                Task {
                    await self.handlePlaybackEnd()
                }
            }
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
        
        self.viewModel.onItemDidPlayToEnd = { [weak self] in
            guard let self else { return }
            Task {
                await self.handlePlaybackEnd()
            }
        }
    }
    
    deinit {
        if let timeObserver {
            viewModel.player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
    
    var playerLayer: AVPlayerLayer {
        viewModel.playerLayer
    }
    
    var isPlaying: Bool { viewModel.player.rate > 0 }

    var onPlaybackTimeChange: ((Double) -> Void)? {
        get { viewModel.onPlaybackTimeChange }
        set { viewModel.onPlaybackTimeChange = newValue }
    }

    var onPlaybackStateChange: ((Bool) -> Void)? {
        get { viewModel.onPlaybackStateChange }
        set { viewModel.onPlaybackStateChange = newValue }
    }

    func updatePreview(draft: EditorDraft, at timelineSeconds: Double, shouldPlay: Bool) async throws {
        latestDraft = draft
        desiredPlayback = shouldPlay

        guard !draft.clips.isEmpty else {
            await MainActor.run {
                clearPlayer()
            }
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
            currentClipSourceStart = segment.clip.sourceStartSeconds
            currentClipDuration = segment.clip.duration
            lastDraftSignature = signature

            await MainActor.run {
                self.viewModel.replaceCurrentItem(with: item)
            }

            try await waitUntilReadyToPlay(item)
        } else {
            currentClipStart = segment.startTime
            currentClipSourceStart = segment.clip.sourceStartSeconds
            currentClipDuration = segment.clip.duration
        }

        let clipSeconds = min(max(clampedTimelineSeconds - segment.startTime, 0), segment.clip.duration)
        let sourceSeconds = segment.clip.sourceStartSeconds + clipSeconds
        try await seekPlayer(to: CMTime(seconds: sourceSeconds, preferredTimescale: 600))

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
        currentClipID = nil
        currentClipStart = 0
        currentClipSourceStart = 0
        currentClipDuration = 0
        lastDraftSignature = nil
        desiredPlayback = false
        isHandlingPlaybackEnd = false
    }

    @MainActor
    private func handlePlaybackEnd() async {
        guard !isHandlingPlaybackEnd else { return }
        isHandlingPlaybackEnd = true
        defer { isHandlingPlaybackEnd = false }

        guard desiredPlayback, let draft = latestDraft else {
            viewModel.pause()
            return
        }

        let nextTimelineTime = currentClipStart + currentClipDuration
        guard nextTimelineTime < draft.totalDuration - 0.001 else {
            desiredPlayback = false
            viewModel.pause()
            viewModel.onPlaybackTimeChange?(draft.totalDuration)
            return
        }

        try? await updatePreview(draft: draft, at: nextTimelineTime, shouldPlay: true)
    }

    private func buildPlayerItem(for clip: TimelineClip) throws -> AVPlayerItem {
        guard let importedClip = clipRepository.findClip(by: clip.importedClipID) else {
            throw NSError(
                domain: "EditorPreview",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未找到对应的素材记录"]
            )
        }
        
        guard let url = PlayerFactory.resolveURL(from: importedClip) else {
            throw NSError(
                domain: "EditorPreview",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "无有效资源地址"]
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
            .map { "\($0.id.uuidString)|\($0.sourceID)|\($0.sourceStartSeconds)|\($0.sourceEndSeconds)|\($0.duration)" }
            .joined(separator: "||")
    }
}
