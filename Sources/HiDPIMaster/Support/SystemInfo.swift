import Foundation

enum SystemInfo {
    /// True on Apple Silicon (even when the app runs under Rosetta).
    static let isAppleSilicon: Bool = {
        // Detect Rosetta translation first
        var translated: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("sysctl.proc_translated", &translated, &size, nil, 0) == 0, translated == 1 {
            return true
        }
        var uts = utsname()
        uname(&uts)
        let machine = withUnsafePointer(to: &uts.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
        }
        return machine.hasPrefix("arm64")
    }()

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.1"
    }

    static var chipDescription: String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var chars = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &chars, &size, nil, 0)
        return String(cString: chars)
    }
}

enum PrivilegedRunner {
    struct RunError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Runs a shell script with administrator privileges (system password prompt).
    static func run(_ script: String) throws {
        let escaped = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        let errPipe = Pipe()
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "unknown error"
            throw RunError(message: msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
