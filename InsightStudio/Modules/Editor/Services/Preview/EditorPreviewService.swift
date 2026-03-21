import Foundation
import AVFoundation
import CoreGraphics

protocol EditorPreviewService: AnyObject {
    var playerLayer: AVPlayerLayer { get }
    var isPlaying: Bool { get }
    var onPlaybackTimeChange: ((Double) -> Void)? { get set }
    var onPlaybackStateChange: ((Bool) -> Void)? { get set }
    func updatePreview(draft: TimelineDraft, at timelineSeconds: Double, shouldPlay: Bool) async throws
}

final class DefaultEditorPreviewService: EditorPreviewService {
    let playerLayer = AVPlayerLayer()
    var isPlaying: Bool { player.rate > 0 }
    var onPlaybackTimeChange: ((Double) -> Void)?
    var onPlaybackStateChange: ((Bool) -> Void)?

    private let player = AVPlayer()
    private let resolver: ClipAssetResolver
    private var lastSignature: String?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(resolver: ClipAssetResolver) {
        self.resolver = resolver
        self.playerLayer.player = player
        self.playerLayer.videoGravity = .resizeAspect
        self.player.automaticallyWaitsToMinimizeStalling = false
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, self.player.rate > 0 else { return }
            self.onPlaybackTimeChange?(max(0, time.seconds))
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.player.pause()
            self?.onPlaybackStateChange?(false)
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

//    func updatePreview(draft: TimelineDraft, at timelineSeconds: Double, shouldPlay: Bool) async throws {
//        guard !draft.clips.isEmpty else {
//            await MainActor.run {
//                self.player.pause()
//                self.player.replaceCurrentItem(with: nil)
//                self.lastSignature = nil
//                self.onPlaybackStateChange?(false)
//            }
//            return
//        }
//
//        let signature = Self.signature(for: draft)
//        if signature != lastSignature {
////            let item = try await buildPlayerItem(for: draft)
//            let item = try await buildPlayerItemMinimal(for: draft)
//            lastSignature = signature
//            await MainActor.run {
//                self.player.replaceCurrentItem(with: item)
//            }
//        }
//
//        let time = CMTime(seconds: min(max(0, timelineSeconds), draft.totalDuration), preferredTimescale: 600)
//        await MainActor.run {
//            self.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
//            if shouldPlay {
//                self.player.playImmediately(atRate: 1.0)
//            } else {
//                self.player.pause()
//            }
//            self.onPlaybackStateChange?(shouldPlay)
//        }
//    }
    
    func updatePreview(
        draft: TimelineDraft,
        at timelineSeconds: Double,
        shouldPlay: Bool
    ) async throws {
        guard !draft.clips.isEmpty else {
            await MainActor.run {
                self.player.pause()
                self.player.replaceCurrentItem(with: nil)
                self.lastSignature = nil
                self.onPlaybackStateChange?(false)
            }
            return
        }

        let signature = Self.signature(for: draft)
        var didReplaceItem = false

        if signature != lastSignature {
            let item = try await buildPlayerItemMinimal(for: draft)
            lastSignature = signature
            didReplaceItem = true

            await MainActor.run {
                self.player.pause()
                self.player.replaceCurrentItem(with: item)
            }

            // 等待 item 至少进入可播放状态
            try await waitUntilReadyToPlay(item)
        }

        let seconds = min(max(0, timelineSeconds), draft.totalDuration)
        let time = CMTime(seconds: seconds, preferredTimescale: 600)

        try await seekPlayer(to: time)

        await MainActor.run {
            if shouldPlay {
                self.player.play()
            } else {
                self.player.pause()
            }
            self.onPlaybackStateChange?(shouldPlay)
        }
    }
    
    private func waitUntilReadyToPlay(_ item: AVPlayerItem) async throws {
        if item.status == .readyToPlay { return }

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
                        domain: "Editor",
                        code: -1001,
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
                            domain: "Editor",
                            code: -1002,
                            userInfo: [NSLocalizedDescriptionKey: "seek 未完成"]
                        ))
                    }
                }
            }
        }
    }
    
    private func buildPlayerItemMinimal(for draft: TimelineDraft) async throws -> AVPlayerItem {
        let composition = AVMutableComposition()

        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(
                domain: "Editor",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "无法创建视频轨道"]
            )
        }

        let compAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero
        var insertedClipCount = 0

        print("========== buildPlayerItemMinimal begin ==========")
        print("draft clips count =", draft.clips.count)

        for (index, clip) in draft.clips.enumerated() {
            print("---- clip[\(index)] begin ----")

            do {
                let asset = try await resolver.resolveAsset(for: clip.asset)

                if let urlAsset = asset as? AVURLAsset {
                    print("clip[\(index)] url =", urlAsset.url.absoluteString)
                    print("clip[\(index)] file exists =", FileManager.default.fileExists(atPath: urlAsset.url.path))
                }

                let isPlayable = try await asset.load(.isPlayable)
                print("clip[\(index)] isPlayable =", isPlayable)
                guard isPlayable else {
                    print("clip[\(index)] skipped: asset 不可播放")
                    continue
                }

                let duration = try await asset.load(.duration)
                print("clip[\(index)] asset duration =", duration.seconds)

                print("clip[\(index)] requested start =", clip.sourceRange.start)
                print("clip[\(index)] requested duration =", clip.sourceRange.duration)
                print("clip[\(index)] requested end =", clip.sourceRange.end)

                let sourceRange = Self.clampedSourceTimeRange(
                    requestedRange: clip.sourceRange,
                    assetDuration: duration
                )

                print("clip[\(index)] actual start =", sourceRange.start.seconds)
                print("clip[\(index)] actual duration =", sourceRange.duration.seconds)
                print("clip[\(index)] actual end =", sourceRange.end.seconds)

                guard sourceRange.duration > .zero else {
                    print("clip[\(index)] skipped: sourceRange 无效")
                    continue
                }

                let sourceVideoTracks = try await asset.loadTracks(withMediaType: .video)
                print("clip[\(index)] video tracks count =", sourceVideoTracks.count)

                guard let sourceVideoTrack = sourceVideoTracks.first else {
                    print("clip[\(index)] skipped: 没有视频轨道")
                    continue
                }

                if insertedClipCount == 0 {
                    let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
                    compVideoTrack.preferredTransform = preferredTransform
                }

                try compVideoTrack.insertTimeRange(sourceRange, of: sourceVideoTrack, at: cursor)
                print("clip[\(index)] video inserted at =", cursor.seconds)

                let sourceAudioTracks = try await asset.loadTracks(withMediaType: .audio)
                print("clip[\(index)] audio tracks count =", sourceAudioTracks.count)

                if let sourceAudioTrack = sourceAudioTracks.first, let compAudioTrack {
                    do {
                        try compAudioTrack.insertTimeRange(sourceRange, of: sourceAudioTrack, at: cursor)
                        print("clip[\(index)] audio inserted")
                    } catch {
                        print("clip[\(index)] audio insert failed:", error)
                    }
                }

                cursor = cursor + sourceRange.duration
                insertedClipCount += 1
                print("clip[\(index)] success, cursor =", cursor.seconds)

            } catch {
                print("clip[\(index)] failed with error:", error)
            }

            print("---- clip[\(index)] end ----")
        }

        print("insertedClipCount =", insertedClipCount)
        print("final cursor =", cursor.seconds)
        print("========== buildPlayerItemMinimal end ==========")

        guard cursor > .zero else {
            throw NSError(
                domain: "Editor",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "没有可播放的有效片段"]
            )
        }

        return AVPlayerItem(asset: composition)
    }

    private func buildPlayerItem(for draft: TimelineDraft) async throws -> AVPlayerItem {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video,
                                                           preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "Editor", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法创建视频轨道"])
        }
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        var instructions: [AVMutableVideoCompositionInstruction] = []
        var cursor = CMTime.zero
        var renderSize = CGSize(width: 1080, height: 1920)

        for clip in draft.clips {
            let asset = try await resolver.resolveAsset(for: clip.asset)
            let sourceVideoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourceTrack = sourceVideoTracks.first else { continue }
            let assetDuration = try? await asset.load(.duration)

            let sourceTimeRange = Self.clampedSourceTimeRange(
                requestedRange: clip.sourceRange,
                assetDuration: assetDuration
            )
            guard sourceTimeRange.duration > .zero else { continue }
            try videoTrack.insertTimeRange(sourceTimeRange, of: sourceTrack, at: cursor)

            if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first,
               let audioTrack {
                try? audioTrack.insertTimeRange(sourceTimeRange, of: sourceAudioTrack, at: cursor)
            }

            let naturalSize = try await sourceTrack.load(.naturalSize)
            let preferredTransform = try await sourceTrack.load(.preferredTransform)
            renderSize = Self.absoluteSize(for: naturalSize.applying(preferredTransform))

            let scaledDurationSeconds = clip.playbackRate > 0
                ? sourceTimeRange.duration.seconds / clip.playbackRate
                : sourceTimeRange.duration.seconds
            let scaledDuration = CMTime(seconds: scaledDurationSeconds, preferredTimescale: 600)
            let insertedRange = CMTimeRange(start: cursor, duration: sourceTimeRange.duration)
            if clip.playbackRate != 1.0 {
                videoTrack.scaleTimeRange(insertedRange, toDuration: scaledDuration)
                if let audioTrack {
                    audioTrack.scaleTimeRange(insertedRange, toDuration: scaledDuration)
                }
            }

            let finalRange = CMTimeRange(start: cursor, duration: scaledDuration)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = finalRange

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            let transform = Self.affineTransform(
                for: clip.transform,
                naturalSize: naturalSize,
                preferredTransform: preferredTransform
            )
            layerInstruction.setTransform(transform, at: cursor)
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)
            cursor = cursor + scaledDuration
        }

        let item = AVPlayerItem(asset: composition)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = instructions
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = renderSize
        item.videoComposition = videoComposition
        return item
    }

    private static func clampedSourceTimeRange(
        requestedRange: TimeRange,
        assetDuration: CMTime?
    ) -> CMTimeRange {
        let requestedStart = max(0, requestedRange.start)
        let requestedDuration = max(0, requestedRange.duration)

        guard let assetDuration,
              assetDuration.isNumeric,
              assetDuration.seconds.isFinite,
              assetDuration.seconds > 0 else {
            return CMTimeRange(
                start: CMTime(seconds: requestedStart, preferredTimescale: 600),
                duration: CMTime(seconds: requestedDuration, preferredTimescale: 600)
            )
        }

        let assetSeconds = assetDuration.seconds
        let clampedStart = min(requestedStart, assetSeconds)
        let remainingDuration = max(0, assetSeconds - clampedStart)
        let clampedDuration = min(requestedDuration, remainingDuration)

        return CMTimeRange(
            start: CMTime(seconds: clampedStart, preferredTimescale: 600),
            duration: CMTime(seconds: clampedDuration, preferredTimescale: 600)
        )
    }

    private static func signature(for draft: TimelineDraft) -> String {
        draft.clips.map {
            "\($0.id.uuidString)-\($0.sourceRange.start)-\($0.sourceRange.duration)-\($0.playbackRate)-\($0.transform.rotationDegrees)-\($0.transform.isMirrored)-\($0.transform.scale)-\($0.transform.translation.x)-\($0.transform.translation.y)"
        }.joined(separator: "|")
    }

    private static func absoluteSize(for size: CGSize) -> CGSize {
        CGSize(width: abs(size.width), height: abs(size.height))
    }

    private static func affineTransform(
        for transform: VideoTransform,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> CGAffineTransform {
        let baseSize = absoluteSize(for: naturalSize.applying(preferredTransform))
        var t = preferredTransform
        t = t.translatedBy(x: transform.translation.x, y: transform.translation.y)
        t = t.translatedBy(x: baseSize.width / 2, y: baseSize.height / 2)
        t = t.scaledBy(x: transform.isMirrored ? -transform.scale : transform.scale, y: transform.scale)
        t = t.rotated(by: transform.rotationDegrees * .pi / 180)
        t = t.translatedBy(x: -baseSize.width / 2, y: -baseSize.height / 2)
        return t
    }
}
