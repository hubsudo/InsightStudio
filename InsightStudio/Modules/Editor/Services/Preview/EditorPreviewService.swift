import Foundation
import AVFoundation
import CoreGraphics

protocol EditorPreviewService: AnyObject {
    var playerLayer: AVPlayerLayer { get }
    func updatePreview(draft: TimelineDraft, at timelineSeconds: Double) async throws
}

final class DefaultEditorPreviewService: EditorPreviewService {
    let playerLayer = AVPlayerLayer()
    private let player = AVPlayer()
    private let resolver: ClipAssetResolver
    private var lastSignature: String?
    private let compositionQueue = DispatchQueue(label: "editor.preview.composition")

    init(resolver: ClipAssetResolver) {
        self.resolver = resolver
        self.playerLayer.player = player
        self.playerLayer.videoGravity = .resizeAspect
        self.player.automaticallyWaitsToMinimizeStalling = false
    }

    func updatePreview(draft: TimelineDraft, at timelineSeconds: Double) async throws {
        let signature = Self.signature(for: draft)
        if signature != lastSignature {
            let item = try await buildPlayerItem(for: draft)
            lastSignature = signature
            await MainActor.run {
                let wasPlaying = self.player.rate > 0
                self.player.replaceCurrentItem(with: item)
                if wasPlaying { self.player.play() }
            }
        }

        let time = CMTime(seconds: max(0, timelineSeconds), preferredTimescale: 600)
        await MainActor.run {
            self.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            self.player.pause()
        }
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

            let sourceTimeRange = CMTimeRange(
                start: CMTime(seconds: clip.sourceRange.start, preferredTimescale: 600),
                duration: CMTime(seconds: clip.sourceRange.duration, preferredTimescale: 600)
            )
            try videoTrack.insertTimeRange(sourceTimeRange, of: sourceTrack, at: cursor)

            if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first,
               let audioTrack {
                try? audioTrack.insertTimeRange(sourceTimeRange, of: sourceAudioTrack, at: cursor)
            }

            let naturalSize = try await sourceTrack.load(.naturalSize)
            let preferredTransform = try await sourceTrack.load(.preferredTransform)
            renderSize = Self.absoluteSize(for: naturalSize.applying(preferredTransform))

            let scaledDuration = CMTime(seconds: clip.renderedDuration, preferredTimescale: 600)
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
