import Foundation
import SwiftData

@Model
final class InstalledApp {
    @Attribute(.unique) var bundleIdentifier: String
    var appName: String
    var installedVersion: String
    var installDate: Date

    init(bundleIdentifier: String, appName: String, installedVersion: String, installDate: Date) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.installedVersion = installedVersion
        self.installDate = installDate
    }
}
