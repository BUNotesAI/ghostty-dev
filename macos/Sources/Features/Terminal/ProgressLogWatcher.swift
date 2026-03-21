import Foundation
import Combine

/// Watches a file at `/tmp/ghostty-progress/<session>.log` for changes and publishes the latest lines.
@MainActor
final class ProgressLogWatcher: ObservableObject {
    @Published var lines: [String] = []
    @Published var allText: String = ""

    private(set) var sessionName: String
    private let dirPath = "/tmp/ghostty-progress"
    private var filePath: String { "\(dirPath)/\(sessionName).log" }
    private nonisolated(unsafe) var fileDescriptor: Int32 = -1
    private nonisolated(unsafe) var source: DispatchSourceFileSystemObject?
    private nonisolated(unsafe) var debounceWork: DispatchWorkItem?

    private static let maxLines = 8

    init(sessionName: String) {
        self.sessionName = sessionName
        ensureDirectory()
        readFile()
        startMonitoring()
    }

    deinit {
        debounceWork?.cancel()
        source?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    // MARK: - Public

    /// Switch to watching a different session log file (e.g. when the tab title changes).
    func updateSessionName(_ newName: String) {
        guard newName != sessionName else { return }
        stopMonitoring()
        sessionName = newName
        ensureDirectory()
        readFile()
        startMonitoring()
    }

    func save(_ text: String) {
        try? text.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    // MARK: - File reading

    private func readFile() {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            lines = []
            allText = ""
            return
        }
        allText = content
        let allLines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        lines = Array(allLines.suffix(Self.maxLines).reversed())
    }

    // MARK: - Directory setup

    private func ensureDirectory() {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: dirPath, isDirectory: &isDir) {
            try? fm.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        // Touch the file so we can open a descriptor
        if !fm.fileExists(atPath: filePath) {
            fm.createFile(atPath: filePath, contents: nil)
        }
    }

    // MARK: - DispatchSource monitoring

    private func startMonitoring() {
        openDescriptor()
        guard fileDescriptor >= 0 else { return }
        createSource()
    }

    private func stopMonitoring() {
        debounceWork?.cancel()
        source?.cancel()
        source = nil
        closeDescriptor()
    }

    private func openDescriptor() {
        closeDescriptor()
        fileDescriptor = open(filePath, O_EVTONLY)
    }

    private func closeDescriptor() {
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func createSource() {
        guard fileDescriptor >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let event = src.data
            if event.contains(.delete) || event.contains(.rename) {
                // File was replaced — reopen
                self.stopMonitoring()
                self.ensureDirectory()
                // Short delay to let the new file settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.readFile()
                    self?.startMonitoring()
                }
            } else {
                self.scheduleRead()
            }
        }
        // No cancel handler — stopMonitoring() and deinit close the descriptor explicitly.
        // A cancel handler here would race with updateSessionName(): the async callback
        // fires after a new descriptor is opened and closes it, leaving the new source dead.
        src.resume()
        self.source = src
    }

    /// Debounce rapid writes — wait 100ms before re-reading.
    private func scheduleRead() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.readFile()
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
}
