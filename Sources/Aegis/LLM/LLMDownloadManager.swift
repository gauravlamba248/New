import Foundation
import Combine

public final class LLMDownloadManager: NSObject, ObservableObject, @unchecked Sendable {
    public static let shared = LLMDownloadManager()

    @Published public var downloadStatuses: [String: DownloadStatus] = [:]

    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var downloadTaskToModelId: [Int: String] = [:]
    private var lastBytesWritten: [String: (bytes: Int64, date: Date)] = [:]
    private let stateLock = NSLock()
    private var session: URLSession!

    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 4
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }

    public func status(for modelId: String) -> DownloadStatus {
        stateLock.lock()
        defer { stateLock.unlock() }
        return downloadStatuses[modelId] ?? .notDownloaded
    }

    public func startDownload(model: LLMModelItem) {
        if model.isDownloaded {
            DispatchQueue.main.async {
                self.downloadStatuses[model.id] = .ready
            }
            return
        }

        stateLock.lock()
        if let existing = activeTasks[model.id] {
            existing.cancel()
        }

        let task = session.downloadTask(with: model.downloadURL)
        let taskId = task.taskIdentifier
        activeTasks[model.id] = task
        downloadTaskToModelId[taskId] = model.id
        lastBytesWritten[model.id] = (0, Date())
        stateLock.unlock()

        DispatchQueue.main.async {
            self.downloadStatuses[model.id] = .downloading(
                progress: 0.0,
                speedMBs: 0.0,
                downloadedBytes: 0,
                totalBytes: model.fileSizeBytes
            )
        }

        task.resume()
    }

    public func cancelDownload(for modelId: String) {
        stateLock.lock()
        if let task = activeTasks[modelId] {
            task.cancel()
            activeTasks.removeValue(forKey: modelId)
        }
        stateLock.unlock()

        DispatchQueue.main.async {
            self.downloadStatuses[modelId] = .notDownloaded
        }
    }

    public func deleteModel(model: LLMModelItem) {
        cancelDownload(for: model.id)
        if FileManager.default.fileExists(atPath: model.localFileURL.path) {
            try? FileManager.default.removeItem(at: model.localFileURL)
        }
        DispatchQueue.main.async {
            self.downloadStatuses[model.id] = .notDownloaded
        }
    }
}

extension LLMDownloadManager: URLSessionDownloadDelegate {
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskId = downloadTask.taskIdentifier

        stateLock.lock()
        guard let modelId = downloadTaskToModelId[taskId] else {
            stateLock.unlock()
            return
        }

        let now = Date()
        var speedMBs: Double = 0.0

        if let prev = lastBytesWritten[modelId] {
            let elapsed = now.timeIntervalSince(prev.date)
            if elapsed >= 0.5 {
                let bytesDiff = totalBytesWritten - prev.bytes
                speedMBs = (Double(bytesDiff) / (1024 * 1024)) / elapsed
                lastBytesWritten[modelId] = (totalBytesWritten, now)
            }
        } else {
            lastBytesWritten[modelId] = (totalBytesWritten, now)
        }
        stateLock.unlock()

        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : 1_000_000_000
        let progress = min(1.0, max(0.0, Double(totalBytesWritten) / Double(total)))

        DispatchQueue.main.async {
            self.downloadStatuses[modelId] = .downloading(
                progress: progress,
                speedMBs: speedMBs,
                downloadedBytes: totalBytesWritten,
                totalBytes: total
            )
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskId = downloadTask.taskIdentifier

        stateLock.lock()
        guard let modelId = downloadTaskToModelId[taskId] else {
            stateLock.unlock()
            return
        }
        stateLock.unlock()

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("Aegis/LLM/Models", isDirectory: true)

        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let originalURL = downloadTask.originalRequest?.url
        let fileName = originalURL?.lastPathComponent ?? "\(modelId.replacingOccurrences(of: "/", with: "_")).gguf"
        let destURL = modelsDir.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: location, to: destURL)

            DispatchQueue.main.async {
                self.downloadStatuses[modelId] = .ready
            }
        } catch {
            DispatchQueue.main.async {
                self.downloadStatuses[modelId] = .error("Failed to save model: \(error.localizedDescription)")
            }
        }

        stateLock.lock()
        activeTasks.removeValue(forKey: modelId)
        downloadTaskToModelId.removeValue(forKey: taskId)
        stateLock.unlock()
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let taskId = task.taskIdentifier

        stateLock.lock()
        guard let modelId = downloadTaskToModelId[taskId] else {
            stateLock.unlock()
            return
        }
        activeTasks.removeValue(forKey: modelId)
        downloadTaskToModelId.removeValue(forKey: taskId)
        stateLock.unlock()

        if let error = error as? URLError, error.code == .cancelled {
            DispatchQueue.main.async {
                self.downloadStatuses[modelId] = .notDownloaded
            }
        } else if let error = error {
            DispatchQueue.main.async {
                self.downloadStatuses[modelId] = .error(error.localizedDescription)
            }
        }
    }
}
