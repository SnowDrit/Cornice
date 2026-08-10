//
//  ScreenGeometry.swift
//  Cornice
//

import AppKit

/// Translation between the two coordinate systems macOS uses at once.
///
/// Accessibility and CoreGraphics measure from the **top left** of the primary display,
/// with y growing downwards. AppKit measures from the **bottom left** of that same
/// display, with y growing upwards. Every value that crosses between them has to be
/// flipped.
///
/// Getting this wrong is invisible on a laptop with one screen, because a window near the
/// middle lands near the middle either way. It shows up the moment a second display is
/// attached, as windows flung far off the top or bottom edge. Keeping the conversion in
/// one place, used by everything, is the only defence.
enum ScreenGeometry {

    /// The display the two coordinate systems share an origin with.
    ///
    /// Not simply `NSScreen.main`, which follows the key window and therefore moves. The
    /// primary display is the one whose frame starts at zero, and that is fixed until the
    /// user rearranges displays in System Settings.
    static var primary: NSScreen? {
        NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first
    }

    private static var primaryHeight: CGFloat {
        primary?.frame.height ?? 0
    }

    /// AppKit point to Accessibility point.
    static func toAX(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// AppKit rectangle to Accessibility rectangle.
    ///
    /// The top edge in flipped coordinates is the bottom edge in unflipped ones, which is
    /// why this uses `maxY` rather than `minY`.
    static func toAX(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height)
    }

    /// The usable area of the display a window sits on, in Accessibility coordinates.
    ///
    /// `visibleFrame` rather than `frame`, so a snapped window stops short of the menu bar
    /// and the Dock instead of hiding underneath them.
    ///
    /// The window is placed by its centre rather than its origin. A window dragged mostly
    /// onto the second display but with its top left corner still on the first belongs to
    /// the display the user sees it on, which is the one holding the larger share of it.
    static func workArea(forWindowAt axFrame: CGRect) -> CGRect? {
        let centre = CGPoint(x: axFrame.midX, y: axFrame.midY)
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        let match = screens.first { toAX($0.frame).contains(centre) }
            ?? screens.max { left, right in
                overlap(axFrame, toAX(left.frame)) < overlap(axFrame, toAX(right.frame))
            }

        guard let match else { return nil }
        return toAX(match.visibleFrame)
    }

    private static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let common = a.intersection(b)
        return common.isNull ? 0 : common.width * common.height
    }
}
