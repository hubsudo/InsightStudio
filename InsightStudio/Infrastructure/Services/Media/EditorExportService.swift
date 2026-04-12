import AVFoundation
import Foundation

struct EditorExportTemplate {
    let name: String
    let exportPresetName: String
    let outputFileType: AVFileType
    let fileExtension: String
    let optimizeForNetworkUse: Bool
    let titlePrefix: String
    let assetIDPrefix: String

    static let libraryDefault = EditorExportTemplate(
        name: "素材库默认导出",
        exportPresetName: AVAssetExportPresetHighestQuality,
        outputFileType: .mp4,
        fileExtension: "mp4",
        optimizeForNetworkUse: false,
        titlePrefix: "编辑结果",
        assetIDPrefix: "edited"
    )

    func makeTitle(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "\(titlePrefix) \(formatter.string(from: date))"
    }

    func makeAssetID() -> String {
        "\(assetIDPrefix)-\(UUID().uuidString.lowercased())"
    }
}

protocol EditorExportService: AnyObject {
    func export(draft: EditorDraft, template: EditorExportTemplate) async throws -> ImportedClip
}

final class DefaultEditorExportService: EditorExportService {
    private let compositionBuilder: TimelineCompositionBuilder
    private let fileStore: EditorImportFileStore

    init(
        compositionBuilder: TimelineCompositionBuilder,
        fileStore: EditorImportFileStore = .shared
    ) {
        self.compositionBuilder = compositionBuilder
        self.fileStore = fileStore
    }

    func export(draft: EditorDraft, template: EditorExportTemplate) async throws -> ImportedClip {
        let composition = try await compositionBuilder.buildComposition(for: draft)
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: template.exportPresetName
        ) else {
            throw NSError(
                domain: "EditorExport",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"]
            )
        }

        guard exportSession.supportedFileTypes.contains(template.outputFileType) else {
            throw NSError(
                domain: "EditorExport",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "当前导出模板不支持所选文件类型"]
            )
        }

        let assetID = template.makeAssetID()
        let outputURL = fileStore.localURL(for: assetID, fileExtension: template.fileExtension)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = template.outputFileType
        exportSession.shouldOptimizeForNetworkUse = template.optimizeForNetworkUse

        let compositionDuration = max(composition.duration.seconds, 0)
        let minimumDuration = min(0.1, max(compositionDuration, 0.1))
        let safeStart = min(max(draft.trimStartSeconds, 0), max(0, compositionDuration - minimumDuration))
        let safeEnd = min(max(draft.trimEndSeconds, safeStart + minimumDuration), compositionDuration)
        let trimDuration = max(safeEnd - safeStart, minimumDuration)
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: safeStart, preferredTimescale: 600),
            duration: CMTime(seconds: trimDuration, preferredTimescale: 600)
        )

        try await exportSession.exportAsync()

        let asset = AVURLAsset(url: outputURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = max(duration.seconds, 0.1)
        let now = Date()

        return ImportedClip(
            sourceID: assetID,
            videoId: assetID,
            title: template.makeTitle(date: now),
            thumbnailURL: "",
            remoteStreamURL: "",
            localFileURL: outputURL,
            durationSeconds: durationSeconds,
            importedAt: now,
            selectedStartSeconds: 0,
            selectedEndSeconds: durationSeconds,
            downloadState: .ready,
            downloadProgress: 1.0,
            sourceKind: .editedResult,
            lastErrorMessage: nil
        )
    }
}

private extension AVAssetExportSession {
    func exportAsync() async throws {
        try await withCheckedThrowingContinuation { continuation in
            exportAsynchronously {
                switch self.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: self.error ?? NSError(
                        domain: "EditorExport",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "导出失败"]
                    ))
                case .cancelled:
                    continuation.resume(throwing: NSError(
                        domain: "EditorExport",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "导出已取消"]
                    ))
                default:
                    continuation.resume(throwing: NSError(
                        domain: "EditorExport",
                        code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "导出未完成"]
                    ))
                }
            }
        }
    }
}
