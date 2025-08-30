import Foundation
import OSLog

#if DEBUG
@MainActor
final class AppPerformanceMetrics: ObservableObject {
    static let shared = AppPerformanceMetrics()

    private let logger = Logger(subsystem: "com.marilena.app", category: "performance")
    private lazy var signposter = OSSignposter(logger: logger)

    private var appLaunchTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var appInitSignpostID: OSSignpostID?

    @Published var firstFrameTime: CFAbsoluteTime?
    @Published var startupDuration: TimeInterval?

    func markAppInit() {
        appLaunchTime = CFAbsoluteTimeGetCurrent()
        let id = signposter.makeSignpostID()
        appInitSignpostID = id
        signposter.beginInterval("AppInit", id: id)
    }

    func markFirstFrame() {
        guard firstFrameTime == nil else { return }
        firstFrameTime = CFAbsoluteTimeGetCurrent()
        startupDuration = (firstFrameTime ?? 0) - appLaunchTime
        if let id = appInitSignpostID {
            signposter.endInterval("AppInit", id: id)
            appInitSignpostID = nil
        }
        if let startupDuration {
            logger.info("🚀 First frame in \(startupDuration, format: .fixed(precision: 2)) s")
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
