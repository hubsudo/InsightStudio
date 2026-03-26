//
//  ClipLibraryPipeline.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/26.
//

import Foundation
import Combine

/// 素材库所有操作
enum ClipLibraryAction {
    case importRequested(ImportedClip)
    case importProgress(id: UUID, progress: Double)
    case importCompleted(id: UUID, localURL: URL, durationSeconds: Double)
    case importFailed(id: UUID, message: String)

    case deleteRequested(ImportedClip)
    case deleteAllRequested

    case restoreFromStorage
}

/// 对外统一发素材库操作对应的响应事件
enum ImportedClipEvent {
    case inserted(ImportedClip)
    case updated(ImportedClip)
    
    case deleted(id: UUID)
    case deletedAll
    
    case restored([ImportedClip])
}

@MainActor
final class ClipLibraryPipeline {
    private let repository: any ClipLibraryRepository
    private let downloadService: any ClipDownloadServiceProtocol
    let importedClip = PassthroughSubject<ImportedClipEvent, Never>()

    init(
        repository: any ClipLibraryRepository,
        downloadService: any ClipDownloadServiceProtocol
    ) {
        self.repository = repository
        self.downloadService = downloadService
    }

    func send(_ action: ClipLibraryAction) {
        switch action {
        case .importRequested(let clip):
            repository.save(clip)
            importedClip.send(.inserted(clip))

        case .importProgress(let id, let progress):
            //先判断 clip 还在不在，避免 cancel 之后可能还有极短窗口收到一次 delegate progress 回调
            guard var clip = repository.findClip(by: id) else { return }
            repository.updateProgress(for: id, progress: progress)
            
            clip.downloadProgress = progress
            clip.downloadState = .downloading
            
//            importedClip.send(.progress(id: id, progress: progress))
            importedClip.send(.updated(clip))

        case .importCompleted(let id, let localURL, let durationSeconds):
            guard var clip = repository.findClip(by: id) else { return }
            repository.markReady(for: id, localFileURL: localURL, durationSeconds: durationSeconds)

            clip.localFileURL = localURL
            clip.durationSeconds = durationSeconds
            clip.downloadState = .ready
            clip.downloadProgress = 1.0
            clip.lastErrorMessage = nil

            importedClip.send(.updated(clip))

        case .importFailed(let id, let message):
            guard var clip = repository.findClip(by: id) else { return }
            repository.markFailed(for: id, message: message)
            
            clip.downloadState = .failed
            clip.lastErrorMessage = message
            
//            importedClip.send(.failed(id: id, message: message))
            importedClip.send(.updated(clip))

        case .deleteRequested(let clip):
            if clip.downloadState == .downloading {
                downloadService.cancelDownload(for: clip.sourceID)
            }
            repository.deleteClip(by: clip.id)
            importedClip.send(.deleted(id: clip.id))

        case .deleteAllRequested:
            let clips = repository.fetchRecentImports()
            for clip in clips where clip.downloadState == .downloading {
                downloadService.cancelDownload(for: clip.sourceID)
            }
            repository.deleteAllClips()
            importedClip.send(.deletedAll)

        case .restoreFromStorage:
            Task { [weak self] in
                guard let self else { return }
//                let restored = await self.repository.reconcileLocalFiles()
//                await self.finishRestore(restored)
                let restored = await self.repository.reconcileLocalFiles()
                await MainActor.run {
                    self.importedClip.send(.restored(restored))
                }
            }
        }
    }
    
//    private func finishRestore(_ clips: [ImportedClip]) {
//        importedClip.send(.restored(clips))
//    }
}
