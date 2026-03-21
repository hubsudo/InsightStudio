import Foundation

protocol TimelineCommand {
    mutating func apply(to draft: inout TimelineDraft)
    mutating func undo(on draft: inout TimelineDraft)
    var description: String { get }
}

enum TimelineTrimHandle {
    case left
    case right
}

struct TrimClipCommand: TimelineCommand {
    let clipID: UUID
    let playheadSeconds: Double
    let handle: TimelineTrimHandle

    private var originalClip: Clip?
    private var updatedClip: Clip?
    private var previousPlayhead: Double?

    var description: String { "Trim Clip" }
    
    init(clipID: UUID, playheadSeconds: Double, handle: TimelineTrimHandle, originalClip: Clip? = nil, updatedClip: Clip? = nil, previousPlayhead: Double? = nil) {
        self.clipID = clipID
        self.playheadSeconds = playheadSeconds
        self.handle = handle
        self.originalClip = originalClip
        self.updatedClip = updatedClip
        self.previousPlayhead = previousPlayhead
    }

    mutating func apply(to draft: inout TimelineDraft) {
        guard let index = draft.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip = draft.clips[index]
        guard let timelineRange = draft.timelineRange(of: clipID) else { return }

        let minRenderedDuration = 0.1
        let clampedPlayhead = min(max(playheadSeconds, timelineRange.start), timelineRange.end)

        var nextClip = clip
        switch handle {
        case .left:
            let nextStart = min(max(clampedPlayhead, timelineRange.start), timelineRange.end - minRenderedDuration)
            let renderedDelta = nextStart - timelineRange.start
            guard renderedDelta > 0 else { return }
            let sourceDelta = renderedDelta * clip.playbackRate
            nextClip.sourceRange.start += sourceDelta
            nextClip.sourceRange.duration -= sourceDelta
        case .right:
            let nextEnd = max(min(clampedPlayhead, timelineRange.end), timelineRange.start + minRenderedDuration)
            let nextRenderedDuration = nextEnd - timelineRange.start
            let nextSourceDuration = nextRenderedDuration * clip.playbackRate
            guard nextSourceDuration < clip.sourceRange.duration else { return }
            nextClip.sourceRange.duration = nextSourceDuration
        }

        guard nextClip.sourceRange.duration > 0 else { return }

        originalClip = clip
        updatedClip = nextClip
        previousPlayhead = draft.playheadSeconds

        draft.clips[index] = nextClip
        draft.selectedClipID = clipID
        draft.playheadSeconds = handle == .left
            ? (draft.timelineRange(of: clipID)?.start ?? clampedPlayhead)
            : (draft.timelineRange(of: clipID)?.end ?? clampedPlayhead)
    }

    mutating func undo(on draft: inout TimelineDraft) {
        guard let originalClip, let updatedClip,
              let index = draft.clips.firstIndex(where: { $0.id == updatedClip.id }) else {
            return
        }
        draft.clips[index] = originalClip
        draft.selectedClipID = originalClip.id
        if let previousPlayhead {
            draft.playheadSeconds = previousPlayhead
        }
    }
}
