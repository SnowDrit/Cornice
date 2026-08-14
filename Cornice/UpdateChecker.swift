//
//  UpdateChecker.swift
//  Cornice
//

import Foundation
import OSLog

/// Asks GitHub whether a newer release exists.
///
/// When the user presses the button, and once at launch if they switched that on. Nothing
/// else: no poll while running, no telemetry, and nothing sent. The request carries no
/// identifier and the reply is a public list of releases. The launch check is off by
/// default so that "no network request unless you ask" stays true for anyone who has not.
///
/// Deliberately not Sparkle, and deliberately not an installer. Cornice finds the release
/// and stops there. Replacing a running application with something just downloaded means
/// first proving the download is genuine, and the builds are ad-hoc signed on the runner,
/// so there is no stable identity to check against: it would come down to trusting
/// whatever the URL returned. This process holds Accessibility and an event tap, and
/// borrowing it borrows those. A real Developer ID in the repository's secrets is what
/// unlocks that conversation, and it is worth more than the updater is.
enum UpdateChecker {

    struct Release: Sendable {
        let version: String
        let url: URL
        let isPrerelease: Bool
    }

    enum Result: Sendable {
        case upToDate
        case available(Release)
        case failed(String)
    }

    private static let endpoint = URL(
        string: "https://api.github.com/repos/SnowDrit/Cornice/releases?per_page=10")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static func check() async -> Result {
        do {
            var request = URLRequest(url: endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                return .failed("GitHub returned \(http.statusCode)")
            }

            guard let entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { return .failed("unexpected response") }

            // `/releases/latest` would be simpler and is wrong here: it skips
            // pre-releases, which is all Cornice publishes at the moment.
            let releases: [Release] = entries.compactMap { entry in
                guard let tag = entry["tag_name"] as? String,
                      let link = entry["html_url"] as? String,
                      let url = URL(string: link),
                      entry["draft"] as? Bool != true
                else { return nil }
                return Release(
                    version: tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV")),
                    url: url,
                    isPrerelease: entry["prerelease"] as? Bool ?? false)
            }

            guard let newest = releases.max(by: { isOlder($0.version, than: $1.version) }) else {
                return .failed("no releases published yet")
            }

            log.info("""
                newest release \(newest.version, privacy: .public), \
                running \(currentVersion, privacy: .public)
                """)
            return isOlder(currentVersion, than: newest.version) ? .available(newest) : .upToDate
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Compares dotted versions numerically, so 0.10 is newer than 0.9, which string
    /// comparison gets backwards, and which is exactly the release where it would start
    /// mattering.
    static func isOlder(_ lhs: String, than rhs: String) -> Bool {
        let left = lhs.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r }
        }
        return false
    }
}
