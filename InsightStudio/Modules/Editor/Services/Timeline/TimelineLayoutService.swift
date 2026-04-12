import Foundation

final class TimelineLayoutService: @unchecked Sendable {
    private let cacheActor = TimelineLayoutCacheActor()

    func makeSnapshot(
        trackID: UUID,
        clips: [TimelineClipLayoutInput],
        key: TimelineLayoutKey,
        viewport: TimelineViewportLayoutRequest
    ) async -> TimelineLayoutSnapshot {
        let plan = await Task.detached(priority: .userInitiated) {
            TimelineLayoutEngine.buildPlan(clips: clips, key: key)
        }.value
        let workload = await cacheActor.prepareTrack(plan: plan, viewport: viewport)

        if workload.visibleClipIDs.isEmpty == false {
            let visibleItems = await Task.detached(priority: .userInitiated) {
                TimelineLayoutEngine.buildItems(clipIDs: workload.visibleClipIDs, plan: plan)
            }.value
            await cacheActor.storeItems(visibleItems, for: trackID, generation: workload.generation)
        }

        return await cacheActor.snapshot(for: trackID, generation: workload.generation)
            ?? TimelineLayoutSnapshot(
                key: key,
                items: [],
                contentWidth: plan.contentWidth,
                generation: workload.generation,
                changedClipIDs: [],
                coveredTimeRanges: [],
                invalidatedTimeRanges: []
            )
    }

    func preheat(
        trackID: UUID,
        clips: [TimelineClipLayoutInput],
        key: TimelineLayoutKey,
        viewport: TimelineViewportLayoutRequest,
        generation: Int
    ) async -> TimelineLayoutSnapshot? {
        let plan = await Task.detached(priority: .utility) {
            TimelineLayoutEngine.buildPlan(clips: clips, key: key)
        }.value
        let preheatClipIDs = await cacheActor.preheatClipIDs(
            for: plan,
            viewport: viewport,
            generation: generation
        )

        guard preheatClipIDs.isEmpty == false else {
            return await cacheActor.snapshot(for: trackID, generation: generation)
        }

        let preheatedItems = await Task.detached(priority: .utility) {
            TimelineLayoutEngine.buildItems(clipIDs: preheatClipIDs, plan: plan)
        }.value
        await cacheActor.storeItems(preheatedItems, for: trackID, generation: generation)
        return await cacheActor.snapshot(for: trackID, generation: generation)
    }

    func invalidateAll() async {
        await cacheActor.invalidateAll()
    }
}
