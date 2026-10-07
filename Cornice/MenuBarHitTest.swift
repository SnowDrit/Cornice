import CoreGraphics

/// Clock interaction must stay inside the visible control. Padding creates an
/// invisible reveal target beside the clock and even below the menu bar.
enum MenuBarHitTest {
    /// Every connected menu bar can expose its own clock. Snapshot order must
    /// not decide which display can open Notification Center.
    nonisolated static func containsClock(point: CGPoint, frames: [CGRect], inMenuBar: Bool) -> Bool {
        frames.contains { containsClock(point: point, frame: $0, inMenuBar: inMenuBar) }
    }

    nonisolated static func containsClock(point: CGPoint, frame: CGRect, inMenuBar: Bool) -> Bool {
        guard inMenuBar, point.x.isFinite, point.y.isFinite,
              !frame.isNull, !frame.isInfinite,
              frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.size.width.isFinite, frame.size.height.isFinite,
              frame.size.width > 0, frame.size.height > 0,
              frame.maxX.isFinite, frame.maxY.isFinite else { return false }
        return frame.contains(point)
    }
}
