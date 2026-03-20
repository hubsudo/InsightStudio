import Foundation

struct UpdatePlaybackRateCommand: TimelineCommand {
    let clipID: UUID
    let newRate: Double
    private var oldRate: Double?

    var description: String { "Update Playback Rate" }
    
    init(clipID: UUID, newRate: Double, oldRate: Double? = nil) {
        self.clipID = clipID
        self.newRate = newRate
        self.oldRate = oldRate
    }

    mutating func apply(to draft: inout TimelineDraft) {
        guard let index = draft.clips.firstIndex(where: { $0.id == clipID }) else { return }
        oldRate = draft.clips[index].playbackRate
        draft.clips[index].playbackRate = max(0.25, min(newRate, 4.0))
        draft.selectedClipID = clipID
    }

    mutating func undo(on draft: inout TimelineDraft) {
        guard let index = draft.clips.firstIndex(where: { $0.id == clipID }), let oldRate else { return }
        draft.clips[index].playbackRate = oldRate
        draft.selectedClipID = clipID
    }
}
