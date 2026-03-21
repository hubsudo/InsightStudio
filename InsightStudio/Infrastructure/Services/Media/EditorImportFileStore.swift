//
//  EditorImportFileStore.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/21.
//

import Foundation

final class EditorImportFileStore {
    static let shared = EditorImportFileStore()

    private let fm = FileManager.default

    private lazy var baseDirectory: URL = {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("EditorImports", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    func localURL(for assetID: String) -> URL {
        baseDirectory.appendingPathComponent("\(assetID).mp4")
    }

    func fileExists(for assetID: String) -> Bool {
        fm.fileExists(atPath: localURL(for: assetID).path)
    }

    func removeFile(for assetID: String) throws {
        let url = localURL(for: assetID)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }
}
