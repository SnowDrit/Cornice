import AppKit

/// Settings describe the saved layout, before native hiding moves its icons.
@MainActor
enum NativeMenuBarArrangement {
    static let didRefresh = Notification.Name("Cornice.nativeMenuBarArrangementDidRefresh")

    static func make(records: [MacOS27MenuBarSnapshot.Record], mainAnchor: CGFloat,
                     zoneAnchor: CGFloat?, classificationScope: MenuBarClassificationScope?) -> SettingsView.Arrangement {
        let running = NSWorkspace.shared.runningApplications
        let runningBundleIDs = Set(running.compactMap(\.bundleIdentifier))
        var names: [String: String] = [:]
        for app in running {
            if let id = app.bundleIdentifier, let name = app.localizedName { names[id] = name }
        }
        var indices: [String: Int] = [:]
        var result = SettingsView.Arrangement(visible: [], hidden: [])
        for record in records.sorted(by: { $0.frame.midX < $1.frame.midX }) {
            guard record.ownerBundleID != Bundle.main.bundleIdentifier else { continue }
            // Match the visibility plan while keeping its revealed geometry:
            // exited apps are absent, but Workspace may omit system hosts.
            guard runningBundleIDs.contains(record.ownerBundleID)
                    || record.ownerBundleID == "com.apple.MenuBarAgent"
                    || record.ownerBundleID == "com.apple.controlcenter" else { continue }
            let index = indices[record.ownerBundleID, default: 0]
            indices[record.ownerBundleID] = index + 1
            let item = MenuBarItem(
                ownerBundleID: record.ownerBundleID,
                ownerName: names[record.ownerBundleID] ?? record.ownerBundleID,
                index: index,
                title: record.title?.isEmpty == false ? record.title : record.description,
                frame: record.frame)
            if classificationScope?.contains(record.frame) != true || record.frame.midX >= mainAnchor {
                result.visible.append(item)
            } else if let zoneAnchor, record.frame.midX < zoneAnchor {
                result.alwaysHidden.append(item)
            } else {
                result.hidden.append(item)
            }
        }
        return result
    }
}
