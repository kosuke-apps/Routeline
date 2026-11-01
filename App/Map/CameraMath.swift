import CoreGraphics
import Foundation
import UIKit

/// The arithmetic that keeps a selection in the part of the map that nothing covers. On a phone a sheet covers the lower part
/// (`bottomInset`); in the wide layout a panel covers the left part (`leadingInset`) and nothing covers the bottom. Kept apart
/// from the map view so that the phone's numbers can be tested to stay what they were.
enum CameraMath {
  /// The map's centre that puts `latitude`, `longitude` in the middle of the free part, `metersPerPoint` being the scale of the
  /// zoom the camera ends at. With only a bottom inset this is the phone's formula: the centre moves south by half the sheet.
  static func flyCenter(
    latitude: Double, longitude: Double, metersPerPoint: Double, bottomInset: CGFloat, leadingInset: CGFloat
  ) -> (latitude: Double, longitude: Double) {
    let south = Double(bottomInset / 2) * metersPerPoint / 111_320
    var west = 0.0
    if leadingInset > 0 {
      west = Double(leadingInset / 2) * metersPerPoint / (111_320 * max(0.01, cos(latitude * .pi / 180)))
    }
    return (latitude - south, longitude - west)
  }

  /// The padding that `fitBounds` leaves around what it shows: room for the buttons at the top and for the sheet at the bottom
  /// (a phone), or for the panel at the left and the controls at the right (wide).
  static func fitPadding(bottomInset: CGFloat, leadingInset: CGFloat, wide: Bool) -> UIEdgeInsets {
    if wide {
      return UIEdgeInsets(top: 100, left: 40 + leadingInset, bottom: 40, right: 80)
    }
    return UIEdgeInsets(top: 130, left: 40, bottom: max(bottomInset, 320) + 30, right: 40)
  }
}
