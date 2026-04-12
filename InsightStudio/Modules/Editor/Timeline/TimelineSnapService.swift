import Foundation

struct TimelineSnapCandidate: Equatable, Sendable {
    let time: Double
    let label: String

    init(time: Double, label: String) {
        self.time = time
        self.label = label
    }
}

enum TimelineSnapService {
    static func nearestTime(
        to proposed: Double,
        in draft: EditorDraft,
        titleProvider: (TimelineClip) -> String = { _ in "Clip" },
        threshold: Double = 0.12
    ) -> Double {
        let candidates = buildCandidates(in: draft, titleProvider: titleProvider)
        guard let nearest = candidates.min(by: { abs($0.time - proposed) < abs($1.time - proposed) }) else {
            return proposed
        }
        return abs(nearest.time - proposed) <= threshold ? nearest.time : proposed
    }

    static func buildCandidates(
        in draft: EditorDraft,
        titleProvider: (TimelineClip) -> String = { _ in "Clip" }
    ) -> [TimelineSnapCandidate] {
        var result: [TimelineSnapCandidate] = [.init(time: 0, label: "Start")]
        var cursor = 0.0
        for clip in draft.videoTrack?.clips ?? [] {
            let title = titleProvider(clip)
            result.append(.init(time: cursor, label: "\(title) Start"))
            cursor += clip.duration
            result.append(.init(time: cursor, label: "\(title) End"))
        }
        return result
    }
}
