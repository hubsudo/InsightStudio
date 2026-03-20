import Foundation

struct DeleteClipCommand: TimelineCommand {
    let clipID: UUID

    private var removedClip: Clip?
    private var removedIndex: Int?
    private var previousSelection: UUID?
    private var previousPlayhead: Double?

    var description: String { "Delete Clip" }

    init(clipID: UUID) {
        self.clipID = clipID
    }

    mutating func apply(to draft: inout TimelineDraft) {
        guard let index = draft.clips.firstIndex(where: { $0.id == clipID }) else { return }

        removedClip = draft.clips[index]
        removedIndex = index
        previousSelection = draft.selectedClipID
        previousPlayhead = draft.playheadSeconds

        draft.clips.remove(at: index)
        if draft.selectedClipID == clipID {
            draft.selectedClipID = draft.clips.indices.contains(index) ? draft.clips[index].id : draft.clips.last?.id
        }
        draft.playheadSeconds = min(draft.playheadSeconds, draft.totalDuration)
    }

    mutating func undo(on draft: inout TimelineDraft) {
        guard let removedClip, let removedIndex else { return }
        let safe = min(max(removedIndex, 0), draft.clips.count)
        draft.clips.insert(removedClip, at: safe)
        draft.selectedClipID = previousSelection ?? removedClip.id
        if let previousPlayhead { draft.playheadSeconds = previousPlayhead }
    }
}
