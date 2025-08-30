import Foundation
import os.signpost

#if DEBUG
@MainActor
final class AppPerformanceMetrics: ObservableObject {
    static let shared = AppPerformanceMetrics()

    private let log = OSLog(subsystem: "com.marilena.app", category: "performance")
    private let signposter = OSSignposter()

    private var appLaunchTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    @Published var firstFrameTime: CFAbsoluteTime?
    @Published var startupDuration: TimeInterval?

    func markAppInit() {
        appLaunchTime = CFAbsoluteTimeGetCurrent()
        os_signpost(.begin, log: log, name: "AppInit")
    }

    func markFirstFrame() {
        guard firstFrameTime == nil else { return }
        firstFrameTime = CFAbsoluteTimeGetCurrent()
        startupDuration = (firstFrameTime ?? 0) - appLaunchTime
        os_signpost(.end, log: log, name: "AppInit")
        if let startupDuration {
            os_log("🚀 First frame in %{public}.2f s", log: log, type: .info, startupDuration)
        }
    }

    func beginInterval(_ name: StaticString) -> OSSignpostID {
        let id = signposter.makeSignpostID()
        signposter.beginInterval(name, id: id)
        return id
    }

    func endInterval(_ name: StaticString, id: OSSignpostID) {
        signposter.endInterval(name, id: id)
    }
}
#endif

