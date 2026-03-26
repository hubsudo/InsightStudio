//
//  ClipDownloadService.swift
//  InsightStudio
//
//  Created by chenrunhuan on 2026/3/21.
//

import Foundation

enum ClipDownloadEvent {
    case progress(Double)
    case completed
}

enum ClipDownloadError: LocalizedError {
    case cancelled
    case invalidResponse
    case moveFileFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "下载已取消"
        case .invalidResponse:
            return "下载失败"
        case .moveFileFailed(let message):
            return "文件落盘失败：\(message)"
        }
    }
}

protocol ClipDownloadServiceProtocol {
    func downloadVideo(
        from remoteURL: URL,
        assetID: String,
        onEvent: @Sendable @escaping (ClipDownloadEvent) -> Void
    ) async throws -> URL
    
    func cancelDownload(for assetID: String)
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
    private var assetIDToTaskID: [String: Int] = [:] // 资源id到任务id的映射，记录用于后续取消
    private let lock = NSLock()
    
    override init() {
        super.init()
    }
    
    func downloadVideo(from remoteURL: URL, assetID: String, onEvent: @Sendable @escaping (ClipDownloadEvent) -> Void) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: remoteURL)
            
            lock.lock()
            taskContexts[task.taskIdentifier] = TaskContext(assetID: assetID, continuation: continuation, onEvent: onEvent)
            assetIDToTaskID[assetID] = task.taskIdentifier
            lock.unlock()
            
            task.resume()
        }
    }
    
    func cancelDownload(for assetID: String) {
        lock.lock()
        let taskID = assetIDToTaskID[assetID]
        lock.unlock()

        guard let taskID else { return }

        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            guard let task = tasks.first(where: { $0.taskIdentifier == taskID }) else { return }
            task.cancel()
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
            context.onEvent(.completed)
            try fm.moveItem(at: location, to: destinationURL)
        } catch {
            context.continuation.resume(
                throwing: ClipDownloadError.moveFileFailed(error.localizedDescription)
            )
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error else { return }
        guard let context = removeContext(for: task) else { return }
        
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            context.continuation.resume(throwing: ClipDownloadError.cancelled)
        } else {
            context.continuation.resume(throwing: error)
        }
    }
}
