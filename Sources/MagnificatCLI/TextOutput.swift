/// Where the CLI writes. Injected so exit codes and stream routing can be tested
/// without spawning a subprocess.
public protocol TextOutput {
    mutating func write(_ text: String)
    mutating func writeError(_ text: String)
}

/// Writes to the real stdout and stderr.
public struct StandardOutput: TextOutput {
    public init() {}
    public mutating func write(_ text: String) { print(text, terminator: "") }
    public mutating func writeError(_ text: String) { FileHandle.standardError.write(text) }
}

import Foundation

extension FileHandle {
    fileprivate func write(_ text: String) { write(Data(text.utf8)) }
}
