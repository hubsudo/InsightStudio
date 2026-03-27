//
//  ClipLibraryPipeline.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/26.
//

import Foundation
import Combine
import AVFoundation

/// 素材库所有操作
enum ClipLibraryAction: Sendable {
    /// 外部 action
    case importRequested(ImportedClip)
    case deleteRequested(ImportedClip)
    case deleteAllRequested
    case restoreFromStorage
    
    /// 状态机闭环关键
    /// 内部action（effect 回来后再次派发）
    case restoreResponse([ImportedClip])
    case importProgress(id: UUID, progress: Double)
    case importCompleted(id: UUID, localURL: URL, durationSeconds: Double)
    case importFailed(id: UUID, message: String)
}

/// 状态机 调度器
@MainActor
final class ClipLibraryPipeline: ObservableObject {
    @Published private(set) var state = ClipLibraryState()
    
    private let repository: any ClipLibraryRepository
    private let downloadService: any ClipDownloadServiceProtocol

    init(
        repository: any ClipLibraryRepository,
        downloadService: any ClipDownloadServiceProtocol
    ) {
        self.repository = repository
        self.downloadService = downloadService
    }

    func send(_ action: ClipLibraryAction) {
        let result = ClipLibraryReducer.reduce(state: state, action: action)
        
        apply(result.mutations)
        run(result.effects)
    }
    
    private func apply(_ mutations: [ClipLibraryMutation]) {
        for mutation in mutations {
            state.apply(mutation)
        }
    }
    
    private func run(_ effects: [ClipLibraryEffect]) {
        for effect in effects {
            run(effect)
        }
    }

    private func run(_ effect: ClipLibraryEffect) {
        switch effect {
        case .none:
            break

        case .restoreFromStorage:
            Task { [weak self] in
                guard let self else { return }
                /// 做较重的磁盘 I/O
                let restored = await self.repository.reconcileLocalFiles()
                self.send(.restoreResponse(restored))
            }

        case .startImport(let clip):
            startImportEffect(clip)

        case .deleteClip(let clip):
            deleteClipEffect(clip)

        case .deleteAll:
            deleteAllEffect()
        }
    }
}

@MainActor
extension ClipLibraryPipeline {
    private func startImportEffect(_ clip: ImportedClip) {
        repository.save(clip)

        Task { [weak self] in
            guard let self else { return }

            do {
                guard let remoteURL = URL(string: clip.remoteStreamURL) else {
                    await self.send(.importFailed(id: clip.id, message: "无效的视频地址"))
                    return
                }

                let localURL = try await self.downloadService.downloadVideo(
                    from: remoteURL,
                    assetID: clip.sourceID
                ) { [weak self] event in
                    guard let self else { return }

                    switch event {
                    case .progress(let progress):
                        Task { @MainActor [weak self] in
                            self?.send(.importProgress(id: clip.id, progress: progress))
                        }

                    case .completed:
                        break
                    }
                }

                let asset = AVURLAsset(url: localURL)
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)

                self.repository.markReady(
                    for: clip.id,
                    localFileURL: localURL,
                    durationSeconds: durationSeconds
                )

                await self.send(
                    .importCompleted(
                        id: clip.id,
                        localURL: localURL,
                        durationSeconds: durationSeconds
                    )
                )

            } catch {
                let message = (error as NSError).localizedDescription
                self.repository.markFailed(for: clip.id, message: message)
                await self.send(.importFailed(id: clip.id, message: message))
            }
        }
    }
    
    private func deleteClipEffect(_ clip: ImportedClip) {
        if clip.downloadState == .downloading {
            downloadService.cancelDownload(for: clip.sourceID)
        }

        repository.deleteClip(by: clip.id)
    }
    
    private func deleteAllEffect() {
        let clips = repository.fetchRecentImports()

        for clip in clips where clip.downloadState == .downloading {
            downloadService.cancelDownload(for: clip.sourceID)
        }

        repository.deleteAllClips()
    }
}
