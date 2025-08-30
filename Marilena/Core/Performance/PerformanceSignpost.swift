import Foundation
import os.signpost

enum PerformanceSignpost {
    private static let log = OSLog(subsystem: "com.marilena.app", category: "performance")

    static func event(_ name: StaticString) {
        #if DEBUG
        os_signpost(.event, log: log, name: name)
        #endif
    }
}

