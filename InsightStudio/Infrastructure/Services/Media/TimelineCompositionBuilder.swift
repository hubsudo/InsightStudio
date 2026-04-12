import AVFoundation
import Foundation

final class TimelineCompositionBuilder {
    private let clipRepository: any ClipLibraryRepository

    init(clipRepository: any ClipLibraryRepository) {
        self.clipRepository = clipRepository
    }

    func compositionSignature(for draft: EditorDraft) throws -> String {
        try draft.tracks
            .map { track in
                let clipSignature = try track.clips
                    .map { clip in
                        let importedClip = try resolveImportedClip(for: clip)
                        let url = try resolvedURL(for: importedClip)
                        return [
                            clip.id.uuidString,
                            importedClip.id.uuidString,
                            url.absoluteString,
                            String(clip.sourceStartSeconds),
                            String(clip.sourceEndSeconds)
                        ].joined(separator: "|")
                    }
                    .joined(separator: "||")
                return [
                    track.id.uuidString,
                    track.kind.rawValue,
                    clipSignature
                ].joined(separator: "::")
            }
            .joined(separator: "###")
    }

    func buildComposition(for draft: EditorDraft) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        guard let timelineTrack = draft.videoTrack else {
            throw NSError(
                domain: "EditorComposition",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未找到视频轨道"]
            )
        }

        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(
                domain: "EditorComposition",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "创建视频轨道失败"]
            )
        }

        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero
        for clip in timelineTrack.clips {
            let importedClip = try resolveImportedClip(for: clip)
            let asset = AVURLAsset(url: try resolvedURL(for: importedClip))
            let duration = try await asset.load(.duration)
            let assetDurationSeconds = max(duration.seconds, 0)

            let safeStart = min(max(clip.sourceStartSeconds, 0), max(assetDurationSeconds - 0.1, 0))
            let safeDuration = min(max(clip.duration, 0.1), max(assetDurationSeconds - safeStart, 0))
            guard safeDuration > 0 else { continue }

            let timeRange = CMTimeRange(
                start: CMTime(seconds: safeStart, preferredTimescale: 600),
                duration: CMTime(seconds: safeDuration, preferredTimescale: 600)
            )

            let sourceVideoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourceVideoTrack = sourceVideoTracks.first else {
                throw NSError(
                    domain: "EditorComposition",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "源视频轨道缺失"]
                )
            }

            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: cursor)

            if let audioTrack, let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: cursor)
            }

            cursor = cursor + timeRange.duration
        }

        return composition
    }

    private func resolveImportedClip(for clip: TimelineClip) throws -> ImportedClip {
        guard let importedClip = clipRepository.findClip(by: clip.importedClipID) else {
            throw NSError(
                domain: "EditorComposition",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "未找到对应的素材记录"]
            )
        }
        return importedClip
    }

    private func resolvedURL(for importedClip: ImportedClip) throws -> URL {
        guard let url = PlayerFactory.resolveURL(from: importedClip) else {
            throw NSError(
                domain: "EditorComposition",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "无有效资源地址"]
            )
        }
        return url
    }
}
