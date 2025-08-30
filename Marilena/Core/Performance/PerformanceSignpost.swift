import Foundation
import OSLog

enum PerformanceSignpost {
    #if DEBUG
    private static let logger = Logger(subsystem: "com.marilena.app", category: "performance")
    private static let signposter = OSSignposter(logger: logger)
    #endif

    static func event(_ name: StaticString) {
        #if DEBUG
        signposter.emitEvent(name)
        #endif
    }
}
