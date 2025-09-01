import Foundation
import OSLog
import Combine

#if DEBUG
@MainActor
final class AppPerformanceMetrics: ObservableObject {
    static let shared = AppPerformanceMetrics()

    private let logger = Logger(subsystem: "com.marilena.app", category: "performance")
    private lazy var signposter = OSSignposter(logger: logger)

    private var appLaunchTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var appInitState: OSSignpostIntervalState?

    @Published var firstFrameTime: CFAbsoluteTime?
    @Published var startupDuration: TimeInterval?

    func markAppInit() {
        appLaunchTime = CFAbsoluteTimeGetCurrent()
        appInitState = signposter.beginInterval("AppInit")
    }

    func markFirstFrame() {
        guard firstFrameTime == nil else { return }
        firstFrameTime = CFAbsoluteTimeGetCurrent()
        startupDuration = (firstFrameTime ?? 0) - appLaunchTime
        if let state = appInitState {
            signposter.endInterval("AppInit", state)
            appInitState = nil
        }
        if let startupDuration {
            let s = String(format: "%.2f", startupDuration)
            logger.info("🚀 First frame in \(s, privacy: .public) s")
        }
    }

    func beginInterval(_ name: StaticString) -> OSSignpostIntervalState {
        signposter.beginInterval(name)
    }

    func endInterval(_ name: StaticString, state: OSSignpostIntervalState) {
        signposter.endInterval(name, state)
    }
}
#endif
