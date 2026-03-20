import Foundation
import CoreGraphics
import UIKit

struct TimelineLayoutItem: Equatable {
    let clipID: UUID
    let frame: CGRect
    let startTime: Double
    let endTime: Double
    let title: String
}

struct TimelineLayoutKey: Equatable {
    let clipIDs: [UUID]
    let renderedDurations: [Double]
    let pixelsPerSecond: CGFloat
    let trackHeight: CGFloat
    let contentInset: UIEdgeInsets
}

struct TimelineLayoutCache {
    var key: TimelineLayoutKey?
    var items: [TimelineLayoutItem] = []
}

actor TimelineCacheActor {
    private var cache = TimelineLayoutCache()

    func cachedItems(for key: TimelineLayoutKey) -> [TimelineLayoutItem]? {
        cache.key == key ? cache.items : nil
    }

    func store(items: [TimelineLayoutItem], for key: TimelineLayoutKey) {
        cache.key = key
        cache.items = items
    }

    func invalidate() {
        cache = TimelineLayoutCache()
    }
}

protocol TimelineLayoutService {
    func makeLayout(
        for draft: TimelineDraft,
        pixelsPerSecond: CGFloat,
        trackHeight: CGFloat,
        contentInset: UIEdgeInsets
    ) async -> [TimelineLayoutItem]

    func invalidateCache() async
}

final class DefaultTimelineLayoutService: TimelineLayoutService {
    private let cacheActor = TimelineCacheActor()

    func makeLayout(
        for draft: TimelineDraft,
        pixelsPerSecond: CGFloat,
        trackHeight: CGFloat,
        contentInset: UIEdgeInsets
    ) async -> [TimelineLayoutItem] {
        let key = TimelineLayoutKey(
            clipIDs: draft.clips.map(\.id),
            renderedDurations: draft.clips.map(\.renderedDuration),
            pixelsPerSecond: pixelsPerSecond,
            trackHeight: trackHeight,
            contentInset: contentInset
        )

        if let cached = await cacheActor.cachedItems(for: key) { return cached }

        var result: [TimelineLayoutItem] = []
        var cursor = 0.0
        for clip in draft.clips {
            let width = max(CGFloat(clip.renderedDuration) * pixelsPerSecond, 48)
            let x = contentInset.left + CGFloat(cursor) * pixelsPerSecond
            result.append(
                TimelineLayoutItem(
                    clipID: clip.id,
                    frame: CGRect(x: x, y: contentInset.top, width: width, height: trackHeight),
                    startTime: cursor,
                    endTime: cursor + clip.renderedDuration,
                    title: clip.displayName
                )
            )
            cursor += clip.renderedDuration
        }

        await cacheActor.store(items: result, for: key)
        return result
    }

    func invalidateCache() async {
        await cacheActor.invalidate()
    }
}
