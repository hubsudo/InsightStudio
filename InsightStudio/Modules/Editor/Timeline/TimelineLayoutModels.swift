import Foundation

struct TimelineTimeRange: Equatable, Sendable {
    let start: Double
    let end: Double

    nonisolated init(start: Double, end: Double) {
        let safeStart = max(0, min(start, end))
        let safeEnd = max(safeStart, end)
        self.start = safeStart
        self.end = safeEnd
    }

    nonisolated var duration: Double {
        max(end - start, 0)
    }

    nonisolated func intersects(_ other: TimelineTimeRange) -> Bool {
        start < other.end && other.start < end
    }

    nonisolated func expanded(by buffer: Double, upperBound: Double) -> TimelineTimeRange {
        TimelineTimeRange(
            start: max(0, start - buffer),
            end: min(upperBound, end + buffer)
        )
    }

    nonisolated static func merged(_ ranges: [TimelineTimeRange]) -> [TimelineTimeRange] {
        guard ranges.isEmpty == false else { return [] }
        let sorted = ranges.sorted {
            if abs($0.start - $1.start) > 0.0001 {
                return $0.start < $1.start
            }
            return $0.end < $1.end
        }

        var mergedRanges: [TimelineTimeRange] = []
        mergedRanges.reserveCapacity(sorted.count)

        for range in sorted {
            guard let last = mergedRanges.last else {
                mergedRanges.append(range)
                continue
            }

            if range.start <= last.end + 0.0001 {
                mergedRanges[mergedRanges.count - 1] = TimelineTimeRange(
                    start: last.start,
                    end: max(last.end, range.end)
                )
            } else {
                mergedRanges.append(range)
            }
        }

        return mergedRanges
    }
}

struct TimelineViewportLayoutRequest: Equatable, Sendable {
    let visibleRange: TimelineTimeRange
    let preheatRange: TimelineTimeRange
    let bufferMultiplier: Double

    nonisolated init(
        visibleRange: TimelineTimeRange,
        preheatRange: TimelineTimeRange,
        bufferMultiplier: Double
    ) {
        self.visibleRange = visibleRange
        self.preheatRange = preheatRange
        self.bufferMultiplier = bufferMultiplier
    }
}

struct TimelinePreheatPolicy: Equatable, Sendable {
    let bufferMultiplier: Double
    let minimumBufferSeconds: Double
    let maximumBufferSeconds: Double

    static let editorDefault = TimelinePreheatPolicy(
        bufferMultiplier: 1.5,
        minimumBufferSeconds: 1.0,
        maximumBufferSeconds: 12.0
    )

    nonisolated func makeViewportRequest(
        visibleRange: TimelineTimeRange,
        trackDuration: Double
    ) -> TimelineViewportLayoutRequest {
        let scaledBuffer = visibleRange.duration * bufferMultiplier
        let bufferSeconds = min(
            max(scaledBuffer, minimumBufferSeconds),
            maximumBufferSeconds
        )
        return TimelineViewportLayoutRequest(
            visibleRange: visibleRange,
            preheatRange: visibleRange.expanded(by: bufferSeconds, upperBound: trackDuration),
            bufferMultiplier: bufferMultiplier
        )
    }
}

struct TimelineInsets: Equatable, Sendable {
    let top: Double
    let left: Double
    let bottom: Double
    let right: Double

    nonisolated init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    nonisolated static func == (lhs: TimelineInsets, rhs: TimelineInsets) -> Bool {
        lhs.top == rhs.top
        && lhs.left == rhs.left
        && lhs.bottom == rhs.bottom
        && lhs.right == rhs.right
    }
}

struct TimelineRect: Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    nonisolated init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

struct TimelineLayoutItemModel: Equatable, Sendable, Identifiable {
    let trackID: UUID
    let clipID: UUID
    let rect: TimelineRect
    let startTime: Double
    let endTime: Double
    let title: String

    nonisolated var id: UUID { clipID }

    nonisolated init(trackID: UUID, clipID: UUID, rect: TimelineRect, startTime: Double, endTime: Double, title: String) {
        self.trackID = trackID
        self.clipID = clipID
        self.rect = rect
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
    }

    nonisolated var timeRange: TimelineTimeRange {
        TimelineTimeRange(start: startTime, end: endTime)
    }
}

struct TimelineLayoutKey: Equatable, Sendable {
    let trackID: UUID
    let pixelsPerSecond: Double
    let trackHeight: Double
    let contentInset: TimelineInsets

    nonisolated init(
        trackID: UUID,
        pixelsPerSecond: Double,
        trackHeight: Double,
        contentInset: TimelineInsets
    ) {
        self.trackID = trackID
        self.pixelsPerSecond = pixelsPerSecond
        self.trackHeight = trackHeight
        self.contentInset = contentInset
    }

    nonisolated static func == (lhs: TimelineLayoutKey, rhs: TimelineLayoutKey) -> Bool {
        lhs.trackID == rhs.trackID
        && lhs.pixelsPerSecond == rhs.pixelsPerSecond
        && lhs.trackHeight == rhs.trackHeight
        && lhs.contentInset == rhs.contentInset
    }
}

struct TimelineLayoutSnapshot: Equatable, Sendable {
    let key: TimelineLayoutKey
    let items: [TimelineLayoutItemModel]
    let contentWidth: Double
    let generation: Int
    let changedClipIDs: Set<UUID>
    let coveredTimeRanges: [TimelineTimeRange]
    let invalidatedTimeRanges: [TimelineTimeRange]

    nonisolated init(
        key: TimelineLayoutKey,
        items: [TimelineLayoutItemModel],
        contentWidth: Double,
        generation: Int,
        changedClipIDs: Set<UUID>,
        coveredTimeRanges: [TimelineTimeRange],
        invalidatedTimeRanges: [TimelineTimeRange]
    ) {
        self.key = key
        self.items = items
        self.contentWidth = contentWidth
        self.generation = generation
        self.changedClipIDs = changedClipIDs
        self.coveredTimeRanges = coveredTimeRanges
        self.invalidatedTimeRanges = invalidatedTimeRanges
    }
}

struct TimelineClipLayoutInput: Equatable, Sendable {
    let id: UUID
    let title: String
    let duration: Double

    nonisolated init(id: UUID, title: String, duration: Double) {
        self.id = id
        self.title = title
        self.duration = duration
    }
}

struct TimelineClipIndexModel: Equatable, Sendable {
    let clipID: UUID
    let title: String
    let startTime: Double
    let endTime: Double
    let originX: Double
    let width: Double

    nonisolated var timeRange: TimelineTimeRange {
        TimelineTimeRange(start: startTime, end: endTime)
    }
}

struct TimelineTrackLayoutPlan: Equatable, Sendable {
    let key: TimelineLayoutKey
    let orderedClipIDs: [UUID]
    let indexByClipID: [UUID: TimelineClipIndexModel]
    let contentWidth: Double
    let totalDuration: Double

    nonisolated func clipIDs(intersecting range: TimelineTimeRange) -> [UUID] {
        orderedClipIDs.filter { clipID in
            guard let index = indexByClipID[clipID] else { return false }
            return index.timeRange.intersects(range)
        }
    }

    nonisolated func item(for clipID: UUID) -> TimelineLayoutItemModel? {
        guard let index = indexByClipID[clipID] else { return nil }
        return TimelineLayoutItemModel(
            trackID: key.trackID,
            clipID: clipID,
            rect: TimelineRect(
                x: index.originX,
                y: key.contentInset.top,
                width: index.width,
                height: key.trackHeight
            ),
            startTime: index.startTime,
            endTime: index.endTime,
            title: index.title
        )
    }

    nonisolated var fullRange: TimelineTimeRange {
        TimelineTimeRange(start: 0, end: totalDuration)
    }
}
