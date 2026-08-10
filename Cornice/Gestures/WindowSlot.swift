//
//  WindowSlot.swift
//  Cornice
//

import CoreGraphics

/// Where a gesture puts a window.
///
/// Stage one deliberately stops at halves and the whole screen. Quarters and thirds are
/// the same arithmetic with different fractions, so adding them later is a matter of new
/// cases here and a second swipe in the recogniser, not a rewrite.
enum WindowSlot: Equatable {
    case leftHalf
    case rightHalf
    case fill

    /// `area` is the usable part of the display, already in Accessibility coordinates.
    ///
    /// Widths are rounded so two windows sharing a screen of odd width meet exactly rather
    /// than leaving a one pixel seam, or overlapping by one and drawing a seam anyway.
    func frame(in area: CGRect) -> CGRect {
        let half = (area.width / 2).rounded()
        switch self {
        case .leftHalf:
            return CGRect(x: area.minX, y: area.minY, width: half, height: area.height)
        case .rightHalf:
            return CGRect(
                x: area.minX + half, y: area.minY,
                width: area.width - half, height: area.height)
        case .fill:
            return area
        }
    }
}
