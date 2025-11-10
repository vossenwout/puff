import AppKit
import Foundation

@main
struct PuffMain {
    static func main() {
        Logger.debug("Main entry point")

        do {
            Logger.debug("Starting PuffService")
            try PuffService().run()
            Logger.debug("Completed successfully")
            exit(EXIT_SUCCESS)
        } catch {
            Logger.debug("Error: \(error)")
            PuffService.handle(error)
        }
    }
}

struct PuffService {
    func run() throws {
        let assistantName = try resolveAssistantName()
        Logger.debug("Assistant name: \(assistantName)")
        
        try ensureBundleIdentifierIsPresent()
        Logger.debug("Bundle ID: \(Bundle.main.bundleIdentifier ?? "none")")

        sendNotification(for: assistantName)
        Logger.debug("Notification dispatched")
    }

    private func resolveAssistantName() throws -> String {
        let arguments = CommandLine.arguments.dropFirst()

        guard let assistantName = arguments.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              assistantName.isEmpty == false else {
            throw PuffError.missingAssistantName
        }

        return assistantName
    }

    private func ensureBundleIdentifierIsPresent() throws {
        guard let identifier = Bundle.main.bundleIdentifier,
              identifier.isEmpty == false else {
            throw PuffError.missingBundleIdentifier
        }
    }

    private func sendNotification(for assistantName: String) {
        let notification = NSUserNotification()
        notification.title = assistantName
        notification.informativeText = "Task finished."
        notification.soundName = "Blow"
        notification.deliveryDate = Date()

        let presenter = NotificationPresenter.shared
        let center = NSUserNotificationCenter.default
        center.delegate = presenter

        presenter.reset()
        center.deliver(notification)
        presenter.waitForDelivery()
    }

    static func handle(_ error: Error) -> Never {
        switch error {
        case PuffError.missingAssistantName:
            fputs("Usage: puff <assistant-name>\n", stderr)
            exit(EXIT_FAILURE)
        case PuffError.missingBundleIdentifier:
            fputs("puff-helper must run from inside Puff.app. Rebuild via Scripts/build_and_bundle.sh.\n", stderr)
            exit(EXIT_FAILURE)
        default:
            fputs("Unexpected error: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}

private enum PuffError: Error {
    case missingAssistantName
    case missingBundleIdentifier
}

private enum Logger {
    static let enabled = ProcessInfo.processInfo.environment["PUFF_DEBUG"] == "1"

    static func debug(_ message: String) {
        guard enabled else { return }
        fputs("DEBUG: \(message)\n", stderr)
    }
}

private final class NotificationPresenter: NSObject, NSUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationPresenter()

    private let deliverySemaphore = DispatchSemaphore(value: 0)
    private let timeout: DispatchTimeInterval = .seconds(2)

    func reset() {
        while deliverySemaphore.wait(timeout: .now()) == .success { }
    }

    func waitForDelivery() {
        _ = deliverySemaphore.wait(timeout: .now() + timeout)
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        true
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
        deliverySemaphore.signal()
    }
}
