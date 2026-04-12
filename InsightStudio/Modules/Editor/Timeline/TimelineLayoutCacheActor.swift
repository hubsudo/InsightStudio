import Foundation

actor TimelineLayoutCacheActor {
    private struct TrackCacheBucket: Sendable {
        let key: TimelineLayoutKey
        var generation: Int
        var orderedClipIDs: [UUID]
        var indexByClipID: [UUID: TimelineClipIndexModel]
        var itemCache: [UUID: TimelineLayoutItemModel]
        var contentWidth: Double
        var totalDuration: Double
        var changedClipIDs: Set<UUID>
        var invalidatedTimeRanges: [TimelineTimeRange]
    }

    struct LayoutWorkload: Sendable {
        let generation: Int
        let visibleClipIDs: [UUID]
        let preheatClipIDs: [UUID]
    }

    private var buckets: [UUID: TrackCacheBucket] = [:]
    private var globalGeneration: Int = 0

    func prepareTrack(
        plan: TimelineTrackLayoutPlan,
        viewport: TimelineViewportLayoutRequest
    ) -> LayoutWorkload {
        globalGeneration += 1
        let oldBucket = buckets[plan.key.trackID]

        let removedClipIDs = Set(oldBucket?.orderedClipIDs ?? [])
            .subtracting(plan.orderedClipIDs)
        let invalidatedRanges = mergedInvalidatedRanges(
            oldBucket: oldBucket,
            plan: plan
        )
        let invalidatedClipIDs = Set(plan.clipIDs(intersectingAny: invalidatedRanges))
            .union(removedClipIDs)

        var bucket = TrackCacheBucket(
            key: plan.key,
            generation: globalGeneration,
            orderedClipIDs: plan.orderedClipIDs,
            indexByClipID: plan.indexByClipID,
            itemCache: oldBucket?.itemCache ?? [:],
            contentWidth: plan.contentWidth,
            totalDuration: plan.totalDuration,
            changedClipIDs: invalidatedClipIDs,
            invalidatedTimeRanges: invalidatedRanges
        )

        if oldBucket?.key != plan.key {
            bucket.itemCache.removeAll()
            bucket.invalidatedTimeRanges = plan.totalDuration > 0 ? [plan.fullRange] : []
            bucket.changedClipIDs = Set(plan.orderedClipIDs)
        } else if invalidatedClipIDs.isEmpty == false {
            bucket.itemCache = bucket.itemCache.filter { clipID, _ in
                invalidatedClipIDs.contains(clipID) == false
            }
        }

        bucket.itemCache = bucket.itemCache.filter { clipID, _ in
            plan.indexByClipID[clipID] != nil
        }

        let visibleClipIDs = missingClipIDs(
            in: viewport.visibleRange,
            plan: plan,
            cachedItems: bucket.itemCache
        )
        let preheatClipIDs = missingClipIDs(
            in: viewport.preheatRange,
            plan: plan,
            cachedItems: bucket.itemCache
        ).filter { visibleClipIDs.contains($0) == false }

        buckets[plan.key.trackID] = bucket
        return LayoutWorkload(
            generation: globalGeneration,
            visibleClipIDs: visibleClipIDs,
            preheatClipIDs: preheatClipIDs
        )
    }

    func preheatClipIDs(
        for plan: TimelineTrackLayoutPlan,
        viewport: TimelineViewportLayoutRequest,
        generation: Int
    ) -> [UUID] {
        guard let bucket = buckets[plan.key.trackID], bucket.generation == generation else {
            return []
        }
        return missingClipIDs(
            in: viewport.preheatRange,
            plan: plan,
            cachedItems: bucket.itemCache
        )
    }

    func storeItems(
        _ items: [TimelineLayoutItemModel],
        for trackID: UUID,
        generation: Int
    ) {
        guard var bucket = buckets[trackID], bucket.generation == generation else { return }
        for item in items {
            bucket.itemCache[item.clipID] = item
            bucket.changedClipIDs.insert(item.clipID)
        }
        buckets[trackID] = bucket
    }

    func snapshot(for trackID: UUID, generation: Int) -> TimelineLayoutSnapshot? {
        guard let bucket = buckets[trackID], bucket.generation == generation else { return nil }
        let items = bucket.orderedClipIDs.compactMap { bucket.itemCache[$0] }
        let coveredRanges = TimelineTimeRange.merged(items.map(\.timeRange))
        return TimelineLayoutSnapshot(
            key: bucket.key,
            items: items,
            contentWidth: bucket.contentWidth,
            generation: generation,
            changedClipIDs: bucket.changedClipIDs,
            coveredTimeRanges: coveredRanges,
            invalidatedTimeRanges: bucket.invalidatedTimeRanges
        )
    }

    func invalidateAll() {
        buckets.removeAll()
    }
}

private extension TimelineLayoutCacheActor {
    private func mergedInvalidatedRanges(
        oldBucket: TrackCacheBucket?,
        plan: TimelineTrackLayoutPlan
    ) -> [TimelineTimeRange] {
        guard let oldBucket else {
            return plan.totalDuration > 0 ? [plan.fullRange] : []
        }

        guard oldBucket.key == plan.key else {
            return plan.totalDuration > 0 ? [plan.fullRange] : []
        }

        let oldIDs = oldBucket.orderedClipIDs
        let newIDs = plan.orderedClipIDs
        let maxCount = max(oldIDs.count, newIDs.count)
        var invalidatedRanges: [TimelineTimeRange] = []
        var structuralStartTime: Double?

        for index in 0..<maxCount {
            let oldID = index < oldIDs.count ? oldIDs[index] : nil
            let newID = index < newIDs.count ? newIDs[index] : nil

            switch (oldID, newID) {
            case let (.some(oldID), .some(newID)):
                guard
                    let oldIndex = oldBucket.indexByClipID[oldID],
                    let newIndex = plan.indexByClipID[newID]
                else {
                    structuralStartTime = min(
                        oldBucket.indexByClipID[oldID]?.startTime ?? oldBucket.totalDuration,
                        plan.indexByClipID[newID]?.startTime ?? plan.totalDuration
                    )
                    break
                }

                if oldID != newID {
                    structuralStartTime = min(oldIndex.startTime, newIndex.startTime)
                    break
                }

                let geometryChanged =
                    abs(oldIndex.startTime - newIndex.startTime) > 0.0001
                    || abs(oldIndex.endTime - newIndex.endTime) > 0.0001
                    || abs(oldIndex.originX - newIndex.originX) > 0.0001
                    || abs(oldIndex.width - newIndex.width) > 0.0001

                if geometryChanged {
                    structuralStartTime = min(oldIndex.startTime, newIndex.startTime)
                    break
                }

                if oldIndex.title != newIndex.title {
                    invalidatedRanges.append(oldIndex.timeRange)
                }

            case let (.some(oldID), .none):
                structuralStartTime = oldBucket.indexByClipID[oldID]?.startTime ?? oldBucket.totalDuration
            case let (.none, .some(newID)):
                structuralStartTime = plan.indexByClipID[newID]?.startTime ?? plan.totalDuration
            case (.none, .none):
                break
            }

            if structuralStartTime != nil {
                break
            }
        }

        if let structuralStartTime {
            invalidatedRanges.append(
                TimelineTimeRange(
                    start: structuralStartTime,
                    end: max(oldBucket.totalDuration, plan.totalDuration)
                )
            )
        }

        return TimelineTimeRange.merged(invalidatedRanges)
    }

    func missingClipIDs(
        in range: TimelineTimeRange,
        plan: TimelineTrackLayoutPlan,
        cachedItems: [UUID: TimelineLayoutItemModel]
    ) -> [UUID] {
        plan.clipIDs(intersecting: range).filter { cachedItems[$0] == nil }
    }
}

private extension TimelineTrackLayoutPlan {
    nonisolated func clipIDs(intersectingAny ranges: [TimelineTimeRange]) -> [UUID] {
        guard ranges.isEmpty == false else { return [] }
        return orderedClipIDs.filter { clipID in
            guard let index = indexByClipID[clipID] else { return false }
            return ranges.contains { index.timeRange.intersects($0) }
        }
    }
}
