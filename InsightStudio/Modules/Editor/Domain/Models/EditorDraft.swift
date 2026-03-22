import Foundation

struct EditorDraft: Equatable, Sendable {
    var clips: [TimelineClip]
    var playheadSeconds: Double
    var isPlaying: Bool
    var zoomPixelsPerSecond: Double

    init(
        clips: [TimelineClip] = [],
        playheadSeconds: Double = 0,
        isPlaying: Bool = false,
        zoomPixelsPerSecond: Double = 56
    ) {
        self.clips = clips
        self.playheadSeconds = playheadSeconds
        self.isPlaying = isPlaying
        self.zoomPixelsPerSecond = zoomPixelsPerSecond
    }

    var totalDuration: Double {
        clips.reduce(0) { $0 + $1.duration }
    }
}

extension EditorDraft {
    init(importedClip: ImportedClip) {
        self.init(
            clips: [TimelineClip(importedClip: importedClip)],
            playheadSeconds: 0,
            isPlaying: false
        )
    }
}
