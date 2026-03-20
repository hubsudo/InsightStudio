import Foundation

struct SplitClipCommand: TimelineCommand {
    let clipID: UUID
    let timelineSplitSeconds: Double

    private var originalClip: Clip?
    private var originalIndex: Int?
    private var leftClip: Clip?
    private var rightClip: Clip?
    private var previousSelection: UUID?
    private var previousPlayhead: Double?

    var description: String { "Split Clip" }

    init(clipID: UUID, timelineSplitSeconds: Double) {
        self.clipID = clipID
        self.timelineSplitSeconds = timelineSplitSeconds
    }

    mutating func apply(to draft: inout TimelineDraft) {
        guard let index = draft.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip = draft.clips[index]
        let clipStart = draft.timelineStartTime(of: clipID) ?? 0
        let timelineOffset = timelineSplitSeconds - clipStart
        guard timelineOffset > 0, timelineOffset < clip.renderedDuration else { return }

        let sourceOffset = timelineOffset * clip.playbackRate
        guard sourceOffset > 0, sourceOffset < clip.sourceRange.duration else { return }

        originalClip = clip
        originalIndex = index
        previousSelection = draft.selectedClipID
        previousPlayhead = draft.playheadSeconds

        let left = Clip(asset: clip.asset,
                        displayName: clip.displayName + "-A",
                        sourceRange: .init(start: clip.sourceRange.start, duration: sourceOffset),
                        playbackRate: clip.playbackRate,
                        transform: clip.transform)
        let right = Clip(asset: clip.asset,
                         displayName: clip.displayName + "-B",
                         sourceRange: .init(start: clip.sourceRange.start + sourceOffset,
                                            duration: clip.sourceRange.duration - sourceOffset),
                         playbackRate: clip.playbackRate,
                         transform: clip.transform)
        leftClip = left
        rightClip = right

        draft.clips.remove(at: index)
        draft.clips.insert(contentsOf: [left, right], at: index)
        draft.selectedClipID = right.id
        draft.playheadSeconds = timelineSplitSeconds
    }

    mutating func undo(on draft: inout TimelineDraft) {
        guard let originalClip, let originalIndex, let leftClip, let rightClip else { return }
        draft.clips.removeAll { $0.id == leftClip.id || $0.id == rightClip.id }
        let safe = min(max(originalIndex, 0), draft.clips.count)
        draft.clips.insert(originalClip, at: safe)
        draft.selectedClipID = previousSelection ?? originalClip.id
        if let previousPlayhead { draft.playheadSeconds = previousPlayhead }
    }
}
