import Foundation

struct EditorDraft: Equatable, Sendable {
    var clips: [TimelineClip]
    var playheadSeconds: Double
    var isPlaying: Bool
    var zoomPixelsPerSecond: Double
    var trimStartSeconds: Double
    var trimEndSeconds: Double

    nonisolated init(
        clips: [TimelineClip] = [],
        playheadSeconds: Double = 0,
        isPlaying: Bool = false,
        zoomPixelsPerSecond: Double = 56,
        trimStartSeconds: Double? = nil,
        trimEndSeconds: Double? = nil
    ) {
        self.clips = clips
        let total = clips.reduce(0) { $0 + $1.duration }
        let clampedPlayhead = min(max(playheadSeconds, 0), total)
        self.playheadSeconds = clampedPlayhead
        self.isPlaying = isPlaying
        self.zoomPixelsPerSecond = zoomPixelsPerSecond
        if total <= 0 {
            self.trimStartSeconds = 0
            self.trimEndSeconds = 0
            return
        }

        let minimumTrimDuration = min(0.1, total)
        let defaultStart = 0.0
        let defaultEnd = total
        let requestedStart = trimStartSeconds ?? defaultStart
        let requestedEnd = trimEndSeconds ?? defaultEnd
        let clampedStart = min(max(requestedStart, 0), max(0, total - minimumTrimDuration))
        let clampedEnd = min(max(requestedEnd, clampedStart + minimumTrimDuration), total)
        self.trimStartSeconds = clampedStart
        self.trimEndSeconds = clampedEnd
    }

    var totalDuration: Double {
        clips.reduce(0) { $0 + $1.duration }
    }

    var trimRange: ClosedRange<Double> {
        trimStartSeconds...trimEndSeconds
    }

    mutating func setTrimRange(start: Double, end: Double, minimumDuration: Double = 0.1) {
        let total = totalDuration
        guard total > 0 else {
            trimStartSeconds = 0
            trimEndSeconds = 0
            return
        }
        let minDuration = min(minimumDuration, total)
        let clampedStart = min(max(start, 0), max(0, total - minDuration))
        let clampedEnd = min(max(end, clampedStart + minDuration), total)
        trimStartSeconds = clampedStart
        trimEndSeconds = clampedEnd
    }

    mutating func normalizeTimelineRanges(minimumTrimDuration: Double = 0.1) {
        let total = totalDuration
        playheadSeconds = min(max(playheadSeconds, 0), total)
        setTrimRange(start: trimStartSeconds, end: trimEndSeconds, minimumDuration: minimumTrimDuration)
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
