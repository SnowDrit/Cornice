//
//  WindowSlot.swift
//  Cornice
//

import CoreGraphics

/// Where a gesture puts a window.
///
/// Three independent choices rather than a list of named places. Written as a flat
/// enumeration this would need a case for every combination, and every new fraction would
/// multiply them; written like this, a swipe changes exactly one of the three and the rest
/// stays where the user left it. That is also what makes chaining feel like refining one
/// position rather than jumping between twelve unrelated ones.
struct WindowSlot: Equatable {

    /// Which side of the screen, or the whole width of it.
    enum Column: Equatable {
        case left, right, whole
    }

    /// How much of the width the column takes. Ignored when the column is `whole`.
    enum Width: Equatable {
        case half, third, twoThirds

        /// The order repeating the same direction walks through, and it comes back round
        /// so a fourth swipe undoes the three before it rather than sticking.
        var next: Width {
            switch self {
            case .half:      .third
            case .third:     .twoThirds
            case .twoThirds: .half
            }
        }

        var fraction: CGFloat {
            switch self {
            case .half:      1.0 / 2.0
            case .third:     1.0 / 3.0
            case .twoThirds: 2.0 / 3.0
            }
        }
    }

    /// Full height, or one of the two halves of it.
    enum Row: Equatable {
        case whole, top, bottom
    }

    var column: Column
    var width: Width
    var row: Row

    static let leftHalf = WindowSlot(column: .left, width: .half, row: .whole)
    static let rightHalf = WindowSlot(column: .right, width: .half, row: .whole)
    static let fill = WindowSlot(column: .whole, width: .half, row: .whole)

    /// The slot a swipe leads to, given where the window already is.
    ///
    /// `current` is `nil` when this is the first swipe of a chain, and then the four
    /// directions mean what they have always meant. Once a chain is running, left and
    /// right choose the side and narrow it, and up and down split it top and bottom.
    ///
    /// Down is the odd one: on its own it means put the window back, and only inside a
    /// chain does it mean the lower band. That is worth the small inconsistency, because
    /// undo is the gesture people reach for most and it should not need a modifier or a
    /// wait.
    static func next(after current: WindowSlot?, swipe: SwipeRecognizer.Direction) -> WindowSlot? {
        guard var slot = current else {
            switch swipe {
            case .left:  return .leftHalf
            case .right: return .rightHalf
            case .up:    return .fill
            case .down:  return nil
            }
        }

        switch swipe {
        case .left:
            if slot.column == .left {
                slot.width = slot.width.next
            } else {
                slot.column = .left
                slot.width = .half
            }
        case .right:
            if slot.column == .right {
                slot.width = slot.width.next
            } else {
                slot.column = .right
                slot.width = .half
            }
        case .up:
            slot.row = slot.row == .top ? .whole : .top
        case .down:
            slot.row = slot.row == .bottom ? .whole : .bottom
        }
        return slot
    }

    /// `area` is the usable part of the display, already in Accessibility coordinates.
    ///
    /// Rounded, because a fractional width leaves a hairline of desktop showing between
    /// two windows that are supposed to be touching.
    func frame(in area: CGRect) -> CGRect {
        let columnWidth: CGFloat = column == .whole
            ? area.width
            : (area.width * width.fraction).rounded()

        let x: CGFloat
        switch column {
        case .whole, .left: x = area.minX
        case .right:        x = area.maxX - columnWidth
        }

        let rowHeight = row == .whole ? area.height : (area.height / 2).rounded()
        let y = row == .bottom ? area.maxY - rowHeight : area.minY

        return CGRect(x: x, y: y, width: columnWidth, height: rowHeight)
    }
}
