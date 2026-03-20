//
//  HistoryManager.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/19.
//

import Foundation

public final class HistoryManager {
    public private(set) var draft: TimelineDraft
    private var undoStack: [any TimelineCommand] = []
    private var redoStack: [any TimelineCommand] = []

    public init(initialDraft: TimelineDraft = TimelineDraft()) {
        self.draft = initialDraft
    }

    public func perform<C: TimelineCommand>(_ command: C) {
        var cmd = command
        cmd.apply(to: &draft)
        undoStack.append(cmd)
        redoStack.removeAll()
    }

    public func undo() {
        guard var cmd = undoStack.popLast() else { return }
        cmd.undo(on: &draft)
        redoStack.append(cmd)
    }

    public func redo() {
        guard var cmd = redoStack.popLast() else { return }
        cmd.apply(to: &draft)
        undoStack.append(cmd)
    }


    public func updateSelection(_ clipID: UUID?) {
        draft.selectedClipID = clipID
    }

    public func updatePlayhead(_ seconds: Double) {
        draft.playheadSeconds = max(0, min(seconds, draft.totalDuration))
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
}
