//
//  ClipDownloadService.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/21.
//

import Foundation

final class ClipDownloadService {
    func downloadVideo(from remoteURL: URL, assetID: String) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)

        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw NSError(domain: "Download", code: -1, userInfo: [NSLocalizedDescriptionKey: "下载失败"])
        }

        let destinationURL = EditorImportFileStore.shared.localURL(for: assetID)

        let fm = FileManager.default
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        try fm.moveItem(at: tempURL, to: destinationURL)

        return destinationURL
    }
}
