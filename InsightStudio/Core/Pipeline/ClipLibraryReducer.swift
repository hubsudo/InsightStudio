//
//  ClipLibraryReducer.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/27.
//

import Foundation

struct ClipLibraryState: Equatable {
    var clips: [ImportedClip] = []
    var isRestoring: Bool = false
    var isDeletingAll: Bool = false
    var lastErrorMessage: String?
}

enum ClipLibraryMutation {
    case setRestoring(Bool)
    case setDeletingAll(Bool)
    case setClips([ImportedClip])
    case insertClip(ImportedClip)
    case replaceClip(ImportedClip)
    case removeClip(id: UUID)
    case removeAllClips
    case setErrorMessage(String?)
}

enum ClipLibraryEffect {
    case restoreFromStorage
    case startImport(ImportedClip)
    case deleteClip(ImportedClip)
    case deleteAll
    case none
}

/// Action -> Reducer -> Mutation -> State -> ViewModel 映射
enum ClipLibraryReducer {
    static func reduce(
        state: ClipLibraryState,
        action: ClipLibraryAction
    ) -> (mutations: [ClipLibraryMutation], effects: [ClipLibraryEffect]) {
        switch action {

        case .restoreFromStorage:
            return (
                mutations: [
                    .setRestoring(true),
                    .setErrorMessage(nil)
                ],
                effects: [
                    .restoreFromStorage
                ]
            )

        case .restoreResponse(let clips):
            return (
                mutations: [
                    .setRestoring(false),
                    .setClips(clips)
                ],
                effects: []
            )

        case .importRequested(let clip):
            return (
                mutations: [
                    .insertClip(clip),
                    .setErrorMessage(nil)
                ],
                effects: [
                    .startImport(clip)
                ]
            )

        case .importProgress(let id, let progress):
            guard let oldClip = state.clips.first(where: { $0.id == id }) else {
                return ([], [])
            }

            var updated = oldClip
            updated.downloadProgress = progress
            updated.downloadState = .downloading

            return (
                mutations: [
                    .replaceClip(updated)
                ],
                effects: []
            )

        case .importCompleted(let id, let localURL, let durationSeconds):
            guard let oldClip = state.clips.first(where: { $0.id == id }) else {
                return ([], [])
            }

            var updated = oldClip
            updated.localFileURL = localURL
            updated.durationSeconds = durationSeconds
            updated.downloadState = .ready
            updated.downloadProgress = 1.0
            updated.lastErrorMessage = nil

            return (
                mutations: [
                    .replaceClip(updated)
                ],
                effects: []
            )

        case .importFailed(let id, let message):
            guard let oldClip = state.clips.first(where: { $0.id == id }) else {
                return ([], [])
            }

            var updated = oldClip
            updated.downloadState = .failed
            updated.lastErrorMessage = message

            return (
                mutations: [
                    .replaceClip(updated),
                    .setErrorMessage(message)
                ],
                effects: []
            )

        case .deleteRequested(let clip):
            return (
                mutations: [
                    .removeClip(id: clip.id)
                ],
                effects: [
                    .deleteClip(clip)
                ]
            )

        case .deleteAllRequested:
            return (
                mutations: [
                    .setDeletingAll(true),
                    .removeAllClips
                ],
                effects: [
                    .deleteAll
                ]
            )
        }
    }
}

extension ClipLibraryState {
    mutating func apply(_ mutation: ClipLibraryMutation) {
        switch mutation {
        case .setRestoring(let value):
            isRestoring = value

        case .setDeletingAll(let value):
            isDeletingAll = value

        case .setClips(let clips):
            self.clips = clips

        case .insertClip(let clip):
            if let index = clips.firstIndex(where: { $0.id == clip.id }) {
                clips[index] = clip
            } else {
                clips.insert(clip, at: 0)
            }

        case .replaceClip(let clip):
            if let index = clips.firstIndex(where: { $0.id == clip.id }) {
                clips[index] = clip
            } else {
                clips.insert(clip, at: 0)
            }

        case .removeClip(let id):
            clips.removeAll { $0.id == id }

        case .removeAllClips:
            clips.removeAll()
            isDeletingAll = false

        case .setErrorMessage(let message):
            lastErrorMessage = message
        }
    }
}
