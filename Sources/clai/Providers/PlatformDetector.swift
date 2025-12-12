import Foundation

/// Information about the current platform
struct PlatformInfo: Sendable {
    let isMacOS: Bool
    let isLinux: Bool
    let isAppleSilicon: Bool
    let macOSVersion: OperatingSystemVersion?

    /// Whether FoundationModel is available (macOS 26+)
    var supportsFoundationModel: Bool {
        guard isMacOS, let version = macOSVersion else {
            return false
        }
        // macOS 26 = version 26.x
        return version.majorVersion >= 26
    }

    /// Whether MLX is available (Apple Silicon)
    var supportsMLX: Bool {
        isMacOS && isAppleSilicon
    }

    var description: String {
        var parts: [String] = []

        if isMacOS {
            parts.append("macOS")
            if let version = macOSVersion {
                parts.append("\(version.majorVersion).\(version.minorVersion)")
            }
            if isAppleSilicon {
                parts.append("(Apple Silicon)")
            } else {
                parts.append("(Intel)")
            }
        } else if isLinux {
            parts.append("Linux")
        } else {
            parts.append("Unknown platform")
        }

        return parts.joined(separator: " ")
    }
}

/// Detects current platform capabilities
enum PlatformDetector {
    static var current: PlatformInfo {
        let processInfo = ProcessInfo.processInfo

        #if os(macOS)
            let isMacOS = true
            let isLinux = false
            let macOSVersion = processInfo.operatingSystemVersion
            let isAppleSilicon = detectAppleSilicon()
        #elseif os(Linux)
            let isMacOS = false
            let isLinux = true
            let macOSVersion: OperatingSystemVersion? = nil
            let isAppleSilicon = false
        #else
            let isMacOS = false
            let isLinux = false
            let macOSVersion: OperatingSystemVersion? = nil
            let isAppleSilicon = false
        #endif

        return PlatformInfo(
            isMacOS: isMacOS,
            isLinux: isLinux,
            isAppleSilicon: isAppleSilicon,
            macOSVersion: macOSVersion
        )
    }

    #if os(macOS)
        private static func detectAppleSilicon() -> Bool {
            var sysinfo = utsname()
            uname(&sysinfo)
            let machine = withUnsafePointer(to: &sysinfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(validatingCString: $0)
                }
            }
            return machine?.contains("arm64") ?? false
        }
    #endif
}
