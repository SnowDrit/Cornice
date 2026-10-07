//
//  MenuBarVisibilityAssertion.swift
//  Cornice
//

import Darwin
import Foundation

// Runtime API reference (MIT): happy666End/MenuBarHider,
// MenuBarHider/Services/MenuBarAgentBridge.swift. No private framework is linked.
@objc private protocol CorniceAssessmentAssertion: AnyObject {
    @objc(activateWithConfiguration:completionHandler:)
    func activate(with configuration: AnyObject, completionHandler: @escaping (NSError?) -> Void)
    func invalidate()
}

/// Owns the macOS 27 menu-bar restriction, retaining the old restriction until its
/// replacement succeeds. Calls and completions are confined to the main actor.
@MainActor
final class MenuBarVisibilityAssertion {
    enum Failure: LocalizedError {
        case unavailable
        case configurationFailed
        case activationTimedOut

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "The system menu-bar visibility API is unavailable."
            case .configurationFailed:
                return "The menu-bar visibility configuration could not be created."
            case .activationTimedOut:
                return "The system did not apply menu-bar visibility within three seconds."
            }
        }
    }

    private struct Runtime {
        let assertion: NSObject.Type
        let configuration: NSObject.Type
    }

    private struct Request {
        let id: UUID
        let assertion: CorniceAssessmentAssertion
        let timeout: DispatchWorkItem
        let completion: (Error?) -> Void
    }

    private static let configurationInitializer = NSSelectorFromString(
        "initWithAllowedSystemItems:allowedBundleIdentifiers:")

    // Keep the framework loaded for the process lifetime: its objects and blocks
    // can outlive any individual bridge instance.
    private static let runtime: Runtime? = {
        guard #available(macOS 27, *),
              dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore",
                     RTLD_NOW | RTLD_LOCAL) != nil,
              let assertion = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type,
              let configuration = NSClassFromString("MBAssessmentModeConfiguration") as? NSObject.Type,
              assertion.instancesRespond(to: NSSelectorFromString("init")),
              assertion.instancesRespond(to: #selector(CorniceAssessmentAssertion.activate(with:completionHandler:))),
              assertion.instancesRespond(to: #selector(CorniceAssessmentAssertion.invalidate)),
              configuration.instancesRespond(to: configurationInitializer)
        else { return nil }
        return Runtime(assertion: assertion, configuration: configuration)
    }()

    private var active: CorniceAssessmentAssertion?
    private var pending: Request?

    var isAvailable: Bool { Self.runtime != nil }

    /// A later apply or release cancels the earlier pending request without
    /// delivering its completion. Every delivered completion runs at most once.
    func apply(allowedBundleIDs: [String], allowedSystemItems: [Int],
               completion: @escaping (Error?) -> Void) {
        cancelPending()
        guard let runtime = Self.runtime else {
            completion(Failure.unavailable)
            return
        }
        guard let configuration = Self.makeConfiguration(
            runtime.configuration, bundleIDs: allowedBundleIDs, systemItems: allowedSystemItems)
        else {
            completion(Failure.configurationFailed)
            return
        }

        // This is ObjC message dispatch; the private class need not explicitly
        // declare conformance to our local protocol. All selectors were checked.
        let assertion = unsafeBitCast(runtime.assertion.init(), to: CorniceAssessmentAssertion.self)
        let id = UUID()
        let timeout = DispatchWorkItem { [weak self] in
            self?.finish(id: id, error: Failure.activationTimedOut)
        }
        pending = Request(id: id, assertion: assertion, timeout: timeout, completion: completion)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeout)

        assertion.activate(with: configuration) { [weak self, weak assertion] error in
            DispatchQueue.main.async {
                guard let assertion else { return }
                guard let self, self.pending?.id == id else {
                    // An activation can complete after cancellation or timeout.
                    // Invalidate again in that case, but tolerate duplicate
                    // callbacks for the assertion that is currently active.
                    if self?.active !== assertion { assertion.invalidate() }
                    return
                }
                self.finish(id: id, error: error)
            }
        }
    }

    func release() {
        cancelPending()
        let previous = active
        active = nil
        previous?.invalidate()
    }

    isolated deinit {
        pending?.timeout.cancel()
        pending?.assertion.invalidate()
        active?.invalidate()
    }

    private func finish(id: UUID, error: Error?) {
        guard let request = pending, request.id == id else { return }
        pending = nil
        request.timeout.cancel()
        if error != nil {
            request.assertion.invalidate()
        } else {
            let previous = active
            active = request.assertion
            previous?.invalidate()
        }
        request.completion(error)
    }

    private func cancelPending() {
        let previous = pending
        pending = nil
        previous?.timeout.cancel()
        previous?.assertion.invalidate()
    }

    private static func makeConfiguration(_ type: NSObject.Type, bundleIDs: [String],
                                          systemItems: [Int]) -> AnyObject? {
        // alloc's +1 ownership is consumed by init; take ownership of init's
        // result, which can be nil if this private API rejects the configuration.
        guard let allocated = (type as AnyObject)
            .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue()
        else { return nil }
        return allocated.perform(configurationInitializer,
                                 with: systemItems.map { NSNumber(value: $0) } as NSArray,
                                 with: bundleIDs as NSArray)?.takeRetainedValue()
    }
}
