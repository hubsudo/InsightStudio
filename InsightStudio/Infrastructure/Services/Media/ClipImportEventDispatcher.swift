//
//  ClipImportEventDispatcher.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/25.
//

import Foundation
import Combine

@MainActor
final class ClipImportEventDispatcher {
    private let repository: any ClipLibraryRepository
    private let signalCenter: ImportSignalCenter

    init(
        repository: any ClipLibraryRepository,
        signalCenter: ImportSignalCenter
    ) {
        self.repository = repository
        self.signalCenter = signalCenter
    }

    func emitProgress(for id: UUID, progress: Double) {
        repository.updateProgress(for: id, progress: progress)
        signalCenter.importedClip.send(.progress(id: id, progress: progress))
    }

    func emitFailure(for id: UUID, message: String) {
        repository.markFailed(for: id, message: message)
        signalCenter.importedClip.send(.failed(id: id, message: message))
    }
}
