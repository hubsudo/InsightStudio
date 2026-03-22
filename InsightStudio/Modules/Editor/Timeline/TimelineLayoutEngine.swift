import Foundation

enum TimelineLayoutEngine {
    static func buildSnapshot(
        clips: [TimelineClipLayoutInput],
        key: TimelineLayoutKey,
        previous: TimelineLayoutSnapshot?,
        generation: Int
    ) -> TimelineLayoutSnapshot {
        var items: [TimelineLayoutItemModel] = []
        var changedIDs: Set<UUID> = []
        var cursorX = key.contentInset.left
        var cursorTime = 0.0

        for clip in clips {
            let width = max(clip.duration * key.pixelsPerSecond, 1)
            let item = TimelineLayoutItemModel(
                clipID: clip.id,
                rect: TimelineRect(
                    x: cursorX,
                    y: key.contentInset.top,
                    width: width,
                    height: key.trackHeight
                ),
                startTime: cursorTime,
                endTime: cursorTime + clip.duration,
                title: clip.title
            )
            if let old = previous?.items.first(where: { $0.clipID == clip.id }), old == item {
                // no-op
            } else {
                changedIDs.insert(clip.id)
            }
            items.append(item)
            cursorX += width
            cursorTime += clip.duration
        }

        return TimelineLayoutSnapshot(
            key: key,
            items: items,
            contentWidth: cursorX + key.contentInset.right,
            generation: generation,
            changedClipIDs: changedIDs
        )
    }
}
