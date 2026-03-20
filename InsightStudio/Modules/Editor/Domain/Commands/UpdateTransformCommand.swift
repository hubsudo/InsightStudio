import Foundation

struct UpdateTransformCommand: TimelineCommand {
    let clipID: UUID
    let newTransform: VideoTransform
    private var oldTransform: VideoTransform?

    var description: String { "Update Transform" }
    
    init(clipID: UUID, newTransform: VideoTransform, oldTransform: VideoTransform? = nil) {
        self.clipID = clipID
        self.newTransform = newTransform
        self.oldTransform = oldTransform
    }

    mutating func apply(to draft: inout TimelineDraft) {
        guard let index = draft.clips.firstIndex(where: { $0.id == clipID }) else { return }
        oldTransform = draft.clips[index].transform
        draft.clips[index].transform = newTransform
        draft.selectedClipID = clipID
    }

    mutating func undo(on draft: inout TimelineDraft) {
        guard let index = draft.clips.firstIndex(where: { $0.id == clipID }), let oldTransform else { return }
        draft.clips[index].transform = oldTransform
        draft.selectedClipID = clipID
    }
}
