import Foundation

public struct DeleteClipCommand: TimelineCommand {
    public let clipID: UUID

    private var removedClip: Clip?
    private var removedIndex: Int?
    private var previousSelection: UUID?
    private var previousPlayhead: Double?

    public var description: String { "Delete Clip" }

    public init(clipID: UUID) {
        self.clipID = clipID
    }

    public mutating func apply(to draft: inout TimelineDraft) {
        guard let index = draft.clips.firstIndex(where: { $0.id == clipID }) else { return }

        removedClip = draft.clips[index]
        removedIndex = index
        previousSelection = draft.selectedClipID
        previousPlayhead = draft.playheadSeconds

        draft.clips.remove(at: index)

        if draft.selectedClipID == clipID {
            if draft.clips.indices.contains(index) {
                draft.selectedClipID = draft.clips[index].id
            } else {
                draft.selectedClipID = draft.clips.last?.id
            }
        }

        draft.playheadSeconds = min(draft.playheadSeconds, draft.totalDuration)
    }

    public mutating func undo(on draft: inout TimelineDraft) {
        guard let removedClip, let removedIndex else { return }

        let safeIndex = min(max(removedIndex, 0), draft.clips.count)
        draft.clips.insert(removedClip, at: safeIndex)
        draft.selectedClipID = previousSelection
        if let previousPlayhead {
            draft.playheadSeconds = previousPlayhead
        }
    }
}
