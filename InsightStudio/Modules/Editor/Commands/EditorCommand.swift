//
//  EditorCommand.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/22.
//

import Foundation

protocol EditorCommand: Sendable {
    var description: String { get }
    func apply(to draft: inout EditorDraft)
    func makeInverse(from oldDraft: EditorDraft) -> any EditorCommand
}

struct RestoreDraftCommand: EditorCommand {
    let snapshot: EditorDraft
    let description: String

    init(snapshot: EditorDraft, description: String = "Restore Draft") {
        self.snapshot = snapshot
        self.description = description
    }

    func apply(to draft: inout EditorDraft) {
        draft = snapshot
    }

    func makeInverse(from oldDraft: EditorDraft) -> any EditorCommand {
        RestoreDraftCommand(snapshot: oldDraft, description: description)
    }
}

struct AppendClipCommand: EditorCommand {
    let clip: TimelineClip
    let snapToEnd: Bool
    var description: String { "Append Clip" }

    init(clip: TimelineClip, snapToEnd: Bool = true) {
        self.clip = clip
        self.snapToEnd = snapToEnd
    }

    func apply(to draft: inout EditorDraft) {
        draft.clips.append(clip)
        if snapToEnd {
            draft.playheadSeconds = draft.totalDuration
        }
    }

    func makeInverse(from oldDraft: EditorDraft) -> any EditorCommand {
        RestoreDraftCommand(snapshot: oldDraft, description: description)
    }
}

struct SetPlayheadCommand: EditorCommand {
    let seconds: Double
    var description: String { "Move Playhead" }

    init(seconds: Double) {
        self.seconds = seconds
    }

    func apply(to draft: inout EditorDraft) {
        draft.playheadSeconds = max(0, min(seconds, draft.totalDuration))
    }

    func makeInverse(from oldDraft: EditorDraft) -> any EditorCommand {
        RestoreDraftCommand(snapshot: oldDraft, description: description)
    }
}
