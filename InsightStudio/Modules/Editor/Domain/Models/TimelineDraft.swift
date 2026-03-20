import Foundation
import CoreGraphics

struct TimeRange: Equatable {
    var start: Double
    var duration: Double

    var end: Double { start + duration }
}

enum ClipAsset: Equatable {
    case localFile(url: URL)
    case remoteVideo(videoID: String, title: String?, thumbnailURL: URL?)
}

struct VideoTransform: Equatable {
    var rotationDegrees: CGFloat = 0
    var isMirrored: Bool = false
    var scale: CGFloat = 1.0
    var translation: CGPoint = .zero

    static let identity = VideoTransform()
}

struct Clip: Identifiable, Equatable {
    let id: UUID
    let asset: ClipAsset
    var displayName: String
    var sourceRange: TimeRange
    var playbackRate: Double
    var transform: VideoTransform

    init(
        id: UUID = UUID(),
        asset: ClipAsset,
        displayName: String,
        sourceRange: TimeRange,
        playbackRate: Double = 1.0,
        transform: VideoTransform = .identity
    ) {
        self.id = id
        self.asset = asset
        self.displayName = displayName
        self.sourceRange = sourceRange
        self.playbackRate = playbackRate
        self.transform = transform
    }

    var renderedDuration: Double {
        guard playbackRate > 0 else { return sourceRange.duration }
        return sourceRange.duration / playbackRate
    }
}

struct TimelineDraft: Equatable {
    var clips: [Clip] = []
    var selectedClipID: UUID?
    var playheadSeconds: Double = 0
    var zoomScale: CGFloat = 1.0

    var totalDuration: Double {
        clips.reduce(0) { $0 + $1.renderedDuration }
    }

    func indexOfSelectedClip() -> Int? {
        guard let selectedClipID else { return nil }
        return clips.firstIndex { $0.id == selectedClipID }
    }

    func selectedClip() -> Clip? {
        guard let idx = indexOfSelectedClip() else { return nil }
        return clips[idx]
    }

    func timelineStartTime(of clipID: UUID) -> Double? {
        var cursor = 0.0
        for clip in clips {
            if clip.id == clipID { return cursor }
            cursor += clip.renderedDuration
        }
        return nil
    }
}
