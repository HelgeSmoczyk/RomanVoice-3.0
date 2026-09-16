import Foundation
import CryptoKit
import Combine

@MainActor final class ModelManager: ObservableObject {
    nonisolated static let filename = "Qwen3-1.7B-Q4_K_M.gguf"
    nonisolated static let digest = "d2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5"
    nonisolated static let downloadURL = URL(string: "https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf")!
    @Published var ready = false
    @Published var busy = false
    @Published var progress: Double = 0
    @Published var message = "KI-Modell wird geprüft …"
    @Published var suggestedPolicy: NetworkPolicy = .wifi
    private var downloader: ModelDownload?
    var url: URL { AppFiles.root.appendingPathComponent("Models/" + Self.filename) }
    init() { Task { await verify() } }
    nonisolated static func valid(_ url: URL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 4 * 1024 * 1024), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined() == digest
    }
    func verify() async {
        guard !busy else { return }
        busy = true
        let location = url
        ready = (try? await Task.detached { try Self.valid(location) }.value) ?? false
        message = ready ? "Kostenlose lokale KI bereit" : "KI-Modell fehlt oder ist unvollständig (1,28 GB)."
        busy = false
    }
    func download(policy: NetworkPolicy) {
        guard !busy else { return }
        busy = true; progress = 0; message = "KI wird heruntergeladen …"
        let worker = ModelDownload(cellular: policy == .cellular)
        downloader = worker
        worker.progress = { [weak self] value in Task { @MainActor in self?.progress = value } }
        worker.completion = { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let location):
                    self.message = "Download wird auf Vollständigkeit geprüft …"
                    do {
                        guard try await Task.detached(operation: { try Self.valid(location) }).value else { throw RomanError.message("Die Prüfsumme stimmt nicht. Bitte erneut herunterladen.") }
                        _ = try AppFiles.directory("Models")
                        if FileManager.default.fileExists(atPath: self.url.path) { try FileManager.default.removeItem(at: self.url) }
                        try FileManager.default.moveItem(at: location, to: self.url)
                        self.ready = true; self.message = "Kostenlose lokale KI bereit"
                    } catch { self.message = error.localizedDescription; try? FileManager.default.removeItem(at: location) }
                case .failure(let error): self.message = error.localizedDescription
                }
                self.busy = false; self.downloader = nil
            }
        }
        worker.start()
    }
    func cancel() { downloader?.cancel() }
    func remove() throws { guard !busy else { return }; if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }; ready = false; message = "KI-Modell entfernt" }
}
private final class ModelDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    var progress: (@Sendable (Double) -> Void)?
    var completion: (@Sendable (Result<URL, Error>) -> Void)?
    private var session: URLSession!
    private var task: URLSessionDownloadTask?
    private let cellular: Bool
    private var resumeURL: URL? { try? AppFiles.directory("Models").appendingPathComponent("download.resume") }
    init(cellular: Bool) { self.cellular = cellular; super.init() }
    func start() {
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = cellular; config.allowsExpensiveNetworkAccess = cellular
        config.waitsForConnectivity = true; config.timeoutIntervalForResource = 7200
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        if let url = resumeURL, let data = try? Data(contentsOf: url) {
            task = session.downloadTask(withResumeData: data)
            try? FileManager.default.removeItem(at: url)
        } else { task = session.downloadTask(with: ModelManager.downloadURL) }
        task?.resume()
    }
    func cancel() {
        task?.cancel(byProducingResumeData: { [weak self] data in
            if let data, let url = self?.resumeURL { try? AppFiles.write(data, to: url) }
        })
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) { progress?(Double(totalBytesWritten) / Double(max(1, totalBytesExpectedToWrite))) }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else { throw RomanError.message("Der Modelldownload ist fehlgeschlagen.") }
            let target = try AppFiles.directory("Models").appendingPathComponent(UUID().uuidString + ".download")
            try FileManager.default.moveItem(at: location, to: target)
            completion?(.success(target))
        } catch { completion?(.failure(error)) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            if let data = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data, let url = resumeURL { try? AppFiles.write(data, to: url) }
            completion?(.failure(error))
        }
        session.finishTasksAndInvalidate()
    }
}
