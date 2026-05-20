import Foundation

/// Launch with `-AppStoreScreenshots` (Debug) to open the screenshot harness instead of the splash flow.
enum AppStoreScreenshotMode {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-AppStoreScreenshots")
        #else
        false
        #endif
    }
}
