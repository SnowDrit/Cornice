import CoreGraphics

/// A fully revealed bar whose coordinates can be compared with its dividers.
/// Frames use AX global points, including negative coordinates above the primary.
struct MenuBarClassificationScope: Equatable, Sendable {
    let screenID: UInt32
    let screenFrame: CGRect
    let barFrame: CGRect

    init?(screenID: UInt32, screenFrame: CGRect, menuBarHeight: CGFloat,
          mainWindowFrame: CGRect, zoneWindowFrame: CGRect? = nil) {
        guard screenID != 0, Self.valid(screenFrame),
              menuBarHeight.isFinite, menuBarHeight > 0,
              menuBarHeight <= screenFrame.height else { return nil }
        let nominalBar = CGRect(x: screenFrame.minX, y: screenFrame.minY,
                                width: screenFrame.width, height: menuBarHeight)
        var bottom = nominalBar.maxY
        for frame in [mainWindowFrame, zoneWindowFrame].compactMap({ $0 }) {
            guard Self.valid(frame), screenFrame.contains(frame),
                  nominalBar.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return nil }
            bottom = max(bottom, frame.maxY)
        }
        self.screenID = screenID
        self.screenFrame = screenFrame
        // Real status windows can extend below the nominal thickness, for
        // example y=3...27 with thickness 24. Keep that observed band intact.
        barFrame = CGRect(x: screenFrame.minX, y: screenFrame.minY,
                          width: screenFrame.width, height: bottom - screenFrame.minY)
    }

    /// A partial overlap or another display is unknown, never a hide request.
    func contains(_ frame: CGRect) -> Bool {
        Self.valid(frame) && barFrame.contains(frame)
    }

    private static func valid(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite
            && frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0
            && frame.maxX.isFinite && frame.maxY.isFinite
    }
}
