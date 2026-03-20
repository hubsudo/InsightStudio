import Foundation

struct InsertClipCommand: TimelineCommand {
    let clip: Clip
    let index: Int

    var description: String { "Insert Clip" }

    mutating func apply(to draft: inout TimelineDraft) {
        let safeIndex = min(max(index, 0), draft.clips.count)
        draft.clips.insert(clip, at: safeIndex)
        draft.selectedClipID = clip.id
        draft.playheadSeconds = draft.timelineStartTime(of: clip.id) ?? draft.playheadSeconds
    }

    mutating func undo(on draft: inout TimelineDraft) {
        draft.clips.removeAll { $0.id == clip.id }
        if draft.selectedClipID == clip.id { draft.selectedClipID = nil }
        draft.playheadSeconds = min(draft.playheadSeconds, draft.totalDuration)
    }
}
