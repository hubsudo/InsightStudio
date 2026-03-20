import Foundation

struct MoveClipCommand: TimelineCommand {
    let fromIndex: Int
    let toIndex: Int
    private var previousSelection: UUID?

    var description: String { "Move Clip" }
    
    init(fromIndex: Int, toIndex: Int, previousSelection: UUID? = nil) {
        self.fromIndex = fromIndex
        self.toIndex = toIndex
        self.previousSelection = previousSelection
    }

    mutating func apply(to draft: inout TimelineDraft) {
        guard draft.clips.indices.contains(fromIndex), draft.clips.indices.contains(toIndex) || toIndex == draft.clips.count else { return }
        previousSelection = draft.selectedClipID
        let clip = draft.clips.remove(at: fromIndex)
        let safeTarget = min(max(toIndex, 0), draft.clips.count)
        draft.clips.insert(clip, at: safeTarget)
        draft.selectedClipID = clip.id
    }

    mutating func undo(on draft: inout TimelineDraft) {
        guard let movedID = draft.selectedClipID,
              let currentIndex = draft.clips.firstIndex(where: { $0.id == movedID }) else { return }
        let clip = draft.clips.remove(at: currentIndex)
        let safeOriginal = min(max(fromIndex, 0), draft.clips.count)
        draft.clips.insert(clip, at: safeOriginal)
        draft.selectedClipID = previousSelection ?? clip.id
    }
}
