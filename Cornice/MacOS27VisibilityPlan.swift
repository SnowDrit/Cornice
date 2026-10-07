//
//  MacOS27VisibilityPlan.swift
//  Cornice
//

import Foundation
import CoreGraphics

/// Classifies a fully revealed snapshot before native hiding changes its geometry.
/// Assessment mode controls third-party items per owning bundle, so a visible or
/// unlocated sibling keeps the entire bundle visible.
struct MacOS27VisibilityPlan: Sendable {
    let hiddenBundleIDs: Set<String>
    let allowedSystemItems: [Int]
    /// These requested-visible extras disappear whenever a native assertion is active.
    let visibleSystemItemsRemovedByNative: Set<String>
    /// Unverified extras have no supported per-item control or confirmed hide behavior.
    let unsupportedSystemIdentifiers: Set<String>
    let hiddenItemCount: Int

    var hasHiddenItems: Bool { hiddenItemCount > 0 }

    init(records: [MacOS27MenuBarSnapshot.Record], mainAnchor: CGFloat?,
         zoneAnchor: CGFloat?, hiding: Bool, isZoneOpen: Bool,
         classificationScope: MenuBarClassificationScope?,
         ownBundleID: String = "io.github.snowdrit.Cornice",
         runningBundleIDs: Set<String>? = nil) {
        var bundleRequests: [String: [Bool]] = [:]
        var systemRequests: [Int: [Bool]] = [:]
        var implicitRequests: [String: [Bool]] = [:]
        var visibleImplicitItems: Set<String> = []
        var unsupportedIdentifiers: Set<String> = []

        func shouldHide(_ frame: CGRect) -> Bool {
            guard let classificationScope, classificationScope.contains(frame),
                  let mainAnchor, mainAnchor.isFinite,
                  frame.origin.x.isFinite, frame.origin.y.isFinite,
                  frame.width.isFinite, frame.height.isFinite,
                  frame.width > 0, frame.height > 0,
                  frame.midX.isFinite else { return false }
            if hiding { return frame.midX < mainAnchor }
            guard !isZoneOpen, let zoneAnchor, zoneAnchor.isFinite,
                  zoneAnchor <= mainAnchor else { return false }
            return frame.midX < zoneAnchor
        }

        for record in records {
            let owner = record.ownerBundleID
            guard !owner.isEmpty, owner != ownBundleID else { continue }
            // Cached geometry outlives app termination. A departed owner must
            // not keep assessment active solely for an item that no longer exists.
            // Workspace can omit these system hosts from its application list.
            if let runningBundleIDs, !runningBundleIDs.contains(owner),
               owner != "com.apple.MenuBarAgent", owner != "com.apple.controlcenter" {
                continue
            }
            let hidden = shouldHide(record.frame)

            // Identifiers, never translated labels, establish native system identity.
            if owner.hasPrefix("com.apple."),
               let system = MacOS27MenuBarSnapshot.systemItemIdentifier(for: record.identifier) {
                systemRequests[system, default: []].append(hidden)
                continue
            }

            if owner.hasPrefix("com.apple."), let identifier = record.identifier,
               identifier.hasPrefix("com.apple.menuextra.") {
                // Only observed implicit removals count as achievable hide targets.
                // Expose collateral removals and unknown behavior to the caller.
                if MacOS27MenuBarSnapshot.isImplicitlyHiddenSystemItem(identifier) {
                    implicitRequests[identifier, default: []].append(hidden)
                    if !hidden { visibleImplicitItems.insert(identifier) }
                } else {
                    unsupportedIdentifiers.insert(identifier)
                }
                continue
            }

            // These processes host multiple system items. Hiding the entire owner
            // would bypass the per-item rules and also swallow essential controls.
            guard owner != "com.apple.MenuBarAgent", owner != "com.apple.controlcenter" else {
                continue
            }
            bundleRequests[owner, default: []].append(hidden)
        }

        let hiddenBundles = Set(bundleRequests.compactMap { owner, requests in
            requests.allSatisfy { $0 } ? owner : nil
        })
        hiddenBundleIDs = hiddenBundles

        // Unknown or absent system items remain allowed. The clock and Control
        // Center are always preserved, wherever their frames happen to be reported.
        let protectedSystem: Set<Int> = [2, 8]
        let hiddenSystem = Set(systemRequests.compactMap { identifier, requests in
            !protectedSystem.contains(identifier) && requests.allSatisfy { $0 } ? identifier : nil
        })
        allowedSystemItems = (0..<64).filter { !hiddenSystem.contains($0) }
        visibleSystemItemsRemovedByNative = visibleImplicitItems
        unsupportedSystemIdentifiers = unsupportedIdentifiers
        hiddenItemCount = implicitRequests.values.reduce(0) { count, requests in
                count + (requests.allSatisfy { $0 } ? requests.count : 0)
            }
            + bundleRequests.reduce(0) { count, entry in
                count + (hiddenBundles.contains(entry.key) ? entry.value.count : 0)
            }
            + systemRequests.reduce(0) { count, entry in
                count + (hiddenSystem.contains(entry.key) ? entry.value.count : 0)
            }
    }
}
