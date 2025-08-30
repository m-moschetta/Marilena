import Foundation
import SwiftUI
import Combine

@MainActor
final class DeferredInitializationService: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    struct DeferredTask {
        let name: String
        let delay: TimeInterval
        let action: @MainActor () -> Void
    }

    private var isRunning = false

    func schedule(_ tasks: [DeferredTask]) {
        guard !isRunning else { return }
        isRunning = true
        for task in tasks {
            DispatchQueue.main.asyncAfter(deadline: .now() + task.delay) {
                task.action()
            }
        }
    }
}

