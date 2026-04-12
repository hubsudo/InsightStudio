import Foundation

struct TimelineClip: Hashable, Identifiable, Sendable {
    /// 时间轴片段自身 ID：一个素材插两次，应该有两个不同的 timeline clip id
    let id: UUID
    /// 对应素材库中的 ImportedClip.id
    let importedClipID: UUID
    var title: String

    /// 编辑态：源素材裁剪区间
    var sourceStartSeconds: Double
    var sourceEndSeconds: Double

    init(id: UUID = UUID(),
         importedClipID: UUID,
         title: String,
         sourceStartSeconds: Double,
         sourceEndSeconds: Double,
    ) {
        self.id = id
        self.importedClipID = importedClipID
        self.title = title
        let clampedStart = max(sourceStartSeconds, 0)
        let clampedEnd = max(sourceEndSeconds, clampedStart + 0.1)
        self.sourceStartSeconds = clampedStart
        self.sourceEndSeconds = clampedEnd
    }
}

extension TimelineClip {
    var duration: Double {
        max(sourceEndSeconds - sourceStartSeconds, 0.1)
    }

    init(importedClip: ImportedClip) {
        self.init(
            importedClipID: importedClip.id,
            title: importedClip.title,
            sourceStartSeconds: importedClip.selectedStartSeconds,
            sourceEndSeconds: importedClip.selectedEndSeconds
        )
    }
}
