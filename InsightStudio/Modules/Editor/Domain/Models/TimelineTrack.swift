import Foundation

enum TimelineTrackKind: String, Equatable, Hashable, Sendable {
    case video
}

struct TimelineTrack: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    var kind: TimelineTrackKind
    var name: String
    var clips: [TimelineClip]

    init(
        id: UUID = UUID(),
        kind: TimelineTrackKind = .video,
        name: String = "Video Track",
        clips: [TimelineClip] = []
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.clips = clips
    }
}

extension TimelineTrack {
    nonisolated var duration: Double {
        clips.reduce(0) { $0 + $1.duration }
    }
}
