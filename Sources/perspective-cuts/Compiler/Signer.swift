import Foundation

struct SignerError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

struct Signer: Sendable {
    private static let shortcutsPath = "/usr/bin/shortcuts"

    static func sign(input: URL, output: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: shortcutsPath) else {
            throw SignerError(message: "shortcuts command not found at \(shortcutsPath). Make sure you are running macOS 12 or later.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shortcutsPath)
        process.arguments = ["sign", "--mode", "anyone", "--input", input.path, "--output", output.path]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown signing error"
            throw SignerError(message: "Signing failed (exit \(process.terminationStatus)): \(errorMessage)")
        }
    }
}
