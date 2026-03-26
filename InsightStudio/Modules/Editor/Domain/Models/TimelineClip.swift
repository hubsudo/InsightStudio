import Foundation

struct TimelineClip: Hashable, Identifiable, Sendable {
    /// 时间轴片段自身 ID：一个素材插两次，应该有两个不同的 timeline clip id
    let id: UUID
    /// 对应素材库中的 ImportedClip.id
    let importedClipID: UUID
    /// 对应素材资源主键，可用于找本地文件
    let sourceID: String
    var title: String
    
    /// 编辑态：源素材裁剪区间
    var sourceStartSeconds: Double
    var sourceEndSeconds: Double
    
    var duration: Double

    init(id: UUID = UUID(),
         importedClipID: UUID,
         sourceID: String,
         title: String,
         sourceStartSeconds: Double,
         sourceEndSeconds: Double,
         duration: Double,
    ) {
        self.id = id
        self.importedClipID = importedClipID
        self.sourceID = sourceID
        self.title = title
        self.sourceStartSeconds = sourceStartSeconds
        self.sourceEndSeconds = sourceEndSeconds
        self.duration = duration
    }
}

extension TimelineClip {
    init(importedClip: ImportedClip) {
        let selectedDuration = max(
            importedClip.selectedEndSeconds - importedClip.selectedStartSeconds,
            0.1
        )
        
        self.init(
            importedClipID: importedClip.id,
            sourceID: importedClip.sourceID,
            title: importedClip.title,
            sourceStartSeconds: importedClip.selectedStartSeconds,
            sourceEndSeconds: importedClip.selectedEndSeconds,
            duration: selectedDuration
        )
    }
}
