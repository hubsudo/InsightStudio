//
//  EditorImportFileStore.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/21.
//

import Foundation
import UniformTypeIdentifiers

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
    
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func removeFile(for assetID: String) throws {
        let url = localURL(for: assetID)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    func allLocalFiles() -> [URL] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentTypeKey,
            .fileSizeKey,
            .creationDateKey
        ]
        guard let urls = try? fm.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls.filter { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
                return false
            }

            guard values.isRegularFile == true else {
                return false
            }

            if let contentType = values.contentType {
                return contentType.conforms(to: .movie) || contentType.conforms(to: .video)
            }

            let ext = url.pathExtension.lowercased()
            return ["mp4", "mov", "m4v"].contains(ext)
        }
    }
}
