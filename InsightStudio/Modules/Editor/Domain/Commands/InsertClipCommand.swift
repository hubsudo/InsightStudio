import Foundation

public struct InsertClipCommand: TimelineCommand {
    public let clip: Clip
    public let index: Int

    public var description: String { "Insert Clip" }

    public init(clip: Clip, index: Int) {
        self.clip = clip
        self.index = index
    }

    public mutating func apply(to draft: inout TimelineDraft) {
        let safeIndex = min(max(index, 0), draft.clips.count)
        draft.clips.insert(clip, at: safeIndex)
        draft.selectedClipID = clip.id
        draft.playheadSeconds = timelineStartSeconds(of: clip.id, in: draft) ?? draft.playheadSeconds
    }

    public mutating func undo(on draft: inout TimelineDraft) {
        draft.clips.removeAll { $0.id == clip.id }
        if draft.selectedClipID == clip.id {
            draft.selectedClipID = nil
        }
        draft.playheadSeconds = min(draft.playheadSeconds, draft.totalDuration)
    }

    private func timelineStartSeconds(of clipID: UUID, in draft: TimelineDraft) -> Double? {
        var cursor = 0.0
        for clip in draft.clips {
            if clip.id == clipID { return cursor }
            cursor += clip.renderedDuration
        }
        return nil
    }
}
