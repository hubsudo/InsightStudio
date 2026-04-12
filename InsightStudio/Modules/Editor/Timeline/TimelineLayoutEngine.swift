import Foundation

enum TimelineLayoutEngine {
    nonisolated static func buildPlan(
        clips: [TimelineClipLayoutInput],
        key: TimelineLayoutKey
    ) -> TimelineTrackLayoutPlan {
        var orderedClipIDs: [UUID] = []
        var indexByClipID: [UUID: TimelineClipIndexModel] = [:]
        var cursorX = key.contentInset.left
        var cursorTime = 0.0

        for clip in clips {
            let width = max(clip.duration * key.pixelsPerSecond, 1)
            let item = TimelineClipIndexModel(
                clipID: clip.id,
                title: clip.title,
                startTime: cursorTime,
                endTime: cursorTime + clip.duration,
                originX: cursorX,
                width: width
            )
            orderedClipIDs.append(clip.id)
            indexByClipID[clip.id] = item
            cursorX += width
            cursorTime += clip.duration
        }

        return TimelineTrackLayoutPlan(
            key: key,
            orderedClipIDs: orderedClipIDs,
            indexByClipID: indexByClipID,
            contentWidth: cursorX + key.contentInset.right,
            totalDuration: cursorTime
        )
    }

    nonisolated static func buildItems(
        clipIDs: [UUID],
        plan: TimelineTrackLayoutPlan
    ) -> [TimelineLayoutItemModel] {
        clipIDs.compactMap { plan.item(for: $0) }
    }
}
