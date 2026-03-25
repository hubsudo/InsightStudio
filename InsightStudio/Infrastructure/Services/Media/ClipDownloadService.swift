//
//  ClipDownloadService.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/21.
//

import Foundation

enum ClipDownloadEvent {
    case progress(Double)
    case completed(URL)
}

protocol ClipDownloadServiceProtocol {
    func downloadVideo(
        from remoteURL: URL,
        assetID: String,
        onEvent: @Sendable @escaping (ClipDownloadEvent) -> Void
    ) async throws -> URL
}

final class ClipDownloadService: NSObject, ClipDownloadServiceProtocol {
    private struct TaskContext {
        let assetID: String
        let continuation: CheckedContinuation<URL, Error>
        let onEvent: @Sendable (ClipDownloadEvent) -> Void
    }
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 600
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    private var taskContexts: [Int: TaskContext] = [:]
    private let lock = NSLock()
    
    override init() {
        super.init()
    }
    
    func downloadVideo(from remoteURL: URL, assetID: String, onEvent: @Sendable @escaping (ClipDownloadEvent) -> Void) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: remoteURL)
            
            lock.lock()
            taskContexts[task.taskIdentifier] = TaskContext(assetID: assetID, continuation: continuation, onEvent: onEvent)
            lock.unlock()
            
            task.resume()
        }
    }
    
    private func context(for task: URLSessionTask) -> TaskContext? {
        lock.lock()
        defer { lock.unlock() }
        return taskContexts[task.taskIdentifier]
    }
    
    private func removeContext(for task: URLSessionTask) -> TaskContext? {
        lock.lock()
        defer { lock.unlock() }
        return taskContexts.removeValue(forKey: task.taskIdentifier)
    }
}

extension ClipDownloadService: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard
            let context = context(for: downloadTask),
            totalBytesExpectedToWrite > 0
        else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        context.onEvent(.progress(progress))
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let context = removeContext(for: downloadTask) else { return }
        do {
            let destinationURL = EditorImportFileStore.shared.localURL(for: context.assetID)

            let fm = FileManager.default
            if fm.fileExists(atPath: destinationURL.path) {
                try fm.removeItem(at: destinationURL)
            }
            try fm.moveItem(at: location, to: destinationURL)
        } catch {
            context.continuation.resume(throwing: error)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error, let context = removeContext(for: task) else { return }
        context.continuation.resume(throwing: error)
    }
}
