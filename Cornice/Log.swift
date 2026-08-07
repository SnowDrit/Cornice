//
//  Log.swift
//  Cornice
//

import OSLog

/// Shared logger.
///
/// Much of what Cornice does later sits on undocumented behaviour, where the only way to
/// understand a failure is to see the exact sequence of events that led to it. Logging
/// through `OSLog` means those traces are available in Console.app without a debugger
/// attached, which matters when reproducing a bug requires real menu bar interaction.
///
/// Read them with:
///
///     log stream --predicate 'subsystem == "io.github.snowdrit.Cornice"' --level info
///
let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "io.github.snowdrit.Cornice",
    category: "Cornice"
)
