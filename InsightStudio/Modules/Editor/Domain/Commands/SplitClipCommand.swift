import Foundation

public struct SplitClipCommand: TimelineCommand {
    public let clipID: UUID
    public let timelineSplitSeconds: Double

    private var originalClip: Clip?
    private var originalIndex: Int?
    private var leftClip: Clip?
    private var rightClip: Clip?
    private var previousSelection: UUID?
    private var previousPlayhead: Double?

    public var description: String { "Split Clip" }

    public init(clipID: UUID, timelineSplitSeconds: Double) {
        self.clipID = clipID
        self.timelineSplitSeconds = timelineSplitSeconds
    }

    public mutating func apply(to draft: inout TimelineDraft) {
        guard let index = draft.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip = draft.clips[index]

        let clipStart = timelineStartSeconds(of: clipID, in: draft)
        let offsetOnTimeline = timelineSplitSeconds - clipStart
        guard offsetOnTimeline > 0, offsetOnTimeline < clip.renderedDuration else { return }

        let sourceSplitOffset = offsetOnTimeline * clip.playbackRate
        guard sourceSplitOffset > 0, sourceSplitOffset < clip.sourceRange.duration else { return }

        originalClip = clip
        originalIndex = index
        previousSelection = draft.selectedClipID
        previousPlayhead = draft.playheadSeconds

        let left = Clip(
            asset: clip.asset,
            displayName: "\(clip.displayName)-A",
            sourceRange: TimeRange(
                start: clip.sourceRange.start,
                duration: sourceSplitOffset
            ),
            playbackRate: clip.playbackRate,
            transform: clip.transform,
            animation: clip.animation
        )

        let right = Clip(
            asset: clip.asset,
            displayName: "\(clip.displayName)-B",
            sourceRange: TimeRange(
                start: clip.sourceRange.start + sourceSplitOffset,
                duration: clip.sourceRange.duration - sourceSplitOffset
            ),
            playbackRate: clip.playbackRate,
            transform: clip.transform,
            animation: clip.animation
        )

        leftClip = left
        rightClip = right

        draft.clips.remove(at: index)
        draft.clips.insert(contentsOf: [left, right], at: index)
        draft.selectedClipID = right.id
        draft.playheadSeconds = timelineSplitSeconds
    }

    public mutating func undo(on draft: inout TimelineDraft) {
        guard let originalClip, let originalIndex, let leftClip, let rightClip else { return }

        draft.clips.removeAll { $0.id == leftClip.id || $0.id == rightClip.id }
        let safeIndex = min(max(originalIndex, 0), draft.clips.count)
        draft.clips.insert(originalClip, at: safeIndex)
        draft.selectedClipID = previousSelection ?? originalClip.id
        if let previousPlayhead {
            draft.playheadSeconds = previousPlayhead
        }
    }

    private func timelineStartSeconds(of clipID: UUID, in draft: TimelineDraft) -> Double {
        var cursor = 0.0
        for clip in draft.clips {
            if clip.id == clipID { return cursor }
            cursor += clip.renderedDuration
        }
        return 0
    }
}
