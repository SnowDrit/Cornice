import CoreGraphics

/// AppKit screen coordinates. A display above the main one must not make its
/// whole desktop look like a menu bar merely because its y coordinate is higher.
enum MenuBarPointerRegion {
    nonisolated static func contains(point: CGPoint, screenFrame: CGRect,
                                     menuBarHeight: CGFloat) -> Bool {
        guard point.x.isFinite, point.y.isFinite,
              !screenFrame.isNull, !screenFrame.isInfinite,
              screenFrame.origin.x.isFinite, screenFrame.origin.y.isFinite,
              screenFrame.size.width.isFinite, screenFrame.size.height.isFinite,
              screenFrame.size.width > 0, screenFrame.size.height > 0,
              screenFrame.maxX.isFinite, screenFrame.maxY.isFinite,
              menuBarHeight.isFinite, menuBarHeight > 0,
              menuBarHeight <= screenFrame.height else { return false }
        return point.x >= screenFrame.minX && point.x < screenFrame.maxX
            && point.y >= screenFrame.maxY - menuBarHeight
            && point.y <= screenFrame.maxY
    }
}
