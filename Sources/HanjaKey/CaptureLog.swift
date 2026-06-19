import Foundation

/// Temporary diagnostic logger for the capture pipeline (bug ① multi-line blank-line replacement and
/// bug ② intermittent input drop).
///
/// Appends timestamped, newline-escaped lines to a file so the build/run split works: ASQi runs the
/// app and reproduces the bug, then this file is read back for analysis — no Console.app, no
/// copy/paste. Remove this file (and its call sites in `AXSupport.capture`) once both bugs are fixed.
enum CaptureLog {
    /// Off by default. Flip to true in a local debug build to diagnose capture issues (e.g. the
    /// intermittent input drop ② or 어절 segmentation ③). Output goes to `path` under /tmp, so it never
    /// touches the repo; nothing is written while disabled.
    static var enabled = false
    static let path = "/tmp/hanjakey-capture.log"

    /// Append one timestamped line. `message` is an autoclosure so it costs nothing when disabled.
    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let line = stamp() + " " + message() + "\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: URL(fileURLWithPath: path)) // file didn't exist yet → create it
        }
    }

    /// A visible separator between hotkey presses, so each capture attempt is easy to find.
    static func session() {
        log("──────── capture() ────────")
    }

    /// Render a string with newlines/tabs made visible and its length annotated — essential for the
    /// blank-line bug, where the newlines inside the captured run are the whole story.
    static func vis(_ s: String) -> String {
        let shown = s
            .replacingOccurrences(of: "\n", with: "⏎")
            .replacingOccurrences(of: "\t", with: "⇥")
        return "«\(shown)» (len=\(s.count))"
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
