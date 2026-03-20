import AVFoundation
import Foundation

public struct CompositionBuildResult {
    public let composition: AVMutableComposition
    public let videoComposition: AVMutableVideoComposition?

    public init(
        composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition?
    ) {
        self.composition = composition
        self.videoComposition = videoComposition
    }
}

public final class CompositionBuilder {
    private let resolver: ClipAssetResolver

    public init(resolver: ClipAssetResolver) {
        self.resolver = resolver
    }

    public func build(from draft: TimelineDraft) async throws -> CompositionBuildResult {
        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            return CompositionBuildResult(composition: composition, videoComposition: nil)
        }

        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var renderSize = CGSize(width: 720, height: 1280)

        for clip in draft.clips {
            let asset = try await resolver.resolveAsset(for: clip.asset)
            guard let srcVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                continue
            }

            let srcAudioTrack = try? await asset.loadTracks(withMediaType: .audio).first

            let srcRange = CMTimeRange(
                start: CMTime(seconds: clip.sourceRange.start, preferredTimescale: 600),
                duration: CMTime(seconds: clip.sourceRange.duration, preferredTimescale: 600)
            )

            try videoTrack.insertTimeRange(srcRange, of: srcVideoTrack, at: cursor)
            if let srcAudioTrack, let audioTrack {
                try? audioTrack.insertTimeRange(srcRange, of: srcAudioTrack, at: cursor)
            }

            let instruction = AVMutableVideoCompositionInstruction()
            let segmentDuration = CMTime(seconds: clip.renderedDuration, preferredTimescale: 600)
            instruction.timeRange = CMTimeRange(start: cursor, duration: segmentDuration)

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            let preferredTransform = try await srcVideoTrack.load(.preferredTransform)
            layerInstruction.setTransform(preferredTransform, at: cursor)
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)

            let naturalSize = try await srcVideoTrack.load(.naturalSize)
            if naturalSize.width > 0, naturalSize.height > 0 {
                renderSize = naturalSize
            }

            cursor = cursor + segmentDuration
        }

        guard !instructions.isEmpty else {
            return CompositionBuildResult(composition: composition, videoComposition: nil)
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = instructions
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = renderSize

        return CompositionBuildResult(composition: composition, videoComposition: videoComposition)
    }
}
