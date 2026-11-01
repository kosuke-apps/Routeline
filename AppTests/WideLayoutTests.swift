import HeadwayCore
import SwiftUI
import Testing

@testable import Headway

@Suite struct WideLayoutTests {
  @Test func aPhoneAndANarrowWindowGetThePhoneLayout() {
    #expect(!WideLayout.isWide(width: 430, horizontalSizeClass: .compact))
    #expect(!WideLayout.isWide(width: 390, horizontalSizeClass: nil))
    // An iPad in Split View at a third or a half, or Slide Over.
    #expect(!WideLayout.isWide(width: 320, horizontalSizeClass: .compact))
    #expect(!WideLayout.isWide(width: 506, horizontalSizeClass: .compact))
    #expect(!WideLayout.isWide(width: 688, horizontalSizeClass: .regular))
  }

  @Test func aWideRegularWindowGetsTheWideLayout() {
    #expect(WideLayout.isWide(width: 700, horizontalSizeClass: .regular))
    #expect(WideLayout.isWide(width: 744, horizontalSizeClass: .regular))
    #expect(WideLayout.isWide(width: 1_376, horizontalSizeClass: .regular))
    #expect(WideLayout.isWide(width: 1_032, horizontalSizeClass: nil))
  }

  @Test func aCompactSizeClassNeverGetsTheWideLayoutWhateverTheWidth() {
    #expect(!WideLayout.isWide(width: 1_000, horizontalSizeClass: .compact))
  }

  @Test func thePanelIsNarrowerInASmallerWindowAndTheMapKeepsRoom() {
    #expect(WideLayout.panelWidth(forWidth: 1_032) == 380)
    #expect(WideLayout.panelWidth(forWidth: 744) == 340)
    for width: CGFloat in [700, 744, 834, 1_032, 1_376] {
      #expect(width - WideLayout.leadingInset(forWidth: width) >= 250, "the map keeps at least 250 points at width \(width)")
    }
  }

  @Test func theInsetIsTheRailPlusThePanelPlusTheGaps() {
    let expected: CGFloat = 464  // rail margin 12 + rail 56 + gap 8 + panel 380 + gap 8
    #expect(WideLayout.leadingInset(forWidth: 1_032) == expected)
  }

  @Test func thePanelHoldsWhatTheSheetsHoldAndTheTwoModes() {
    for sheet: ActiveSheet in [.stop("1"), .bus("2"), .trip("t", ServiceDateForTests.value), .journey, .search, .routes, .settings] {
      #expect(WideLayout.showsPanel(mode: .map, sheet: sheet))
      #expect(WideLayout.showsPanel(mode: .plan, sheet: sheet))
    }
    #expect(WideLayout.showsPanel(mode: .info, sheet: nil))
    #expect(WideLayout.showsPanel(mode: .plan, sheet: nil))
    // The map alone has no panel.
    #expect(!WideLayout.showsPanel(mode: .map, sheet: nil))
  }
}

@Suite struct CameraMathTests {
  /// The phone's own formulas, as they were written before the wide layout (kept here to show they did not change).
  private func oldCenter(latitude: Double, longitude: Double, metersPerPoint: Double, bottomInset: CGFloat) -> (Double, Double) {
    let shift = Double(bottomInset / 2) * metersPerPoint / 111_320
    return (latitude - shift, longitude)
  }

  @Test func thePhoneKeepsItsNumbers() {
    for bottom: CGFloat in [0, 320, 480] {
      for (latitude, longitude, scale) in [(43.0731, -89.4012, 4.7), (42.95, -89.3, 19.1), (43.2, -89.5, 0.6)] {
        let now = CameraMath.flyCenter(
          latitude: latitude, longitude: longitude, metersPerPoint: scale, bottomInset: bottom, leadingInset: 0)
        let was = oldCenter(latitude: latitude, longitude: longitude, metersPerPoint: scale, bottomInset: bottom)
        #expect(now.latitude == was.0 && now.longitude == was.1)
      }
    }
  }

  @Test func thePhoneKeepsItsFitPadding() {
    for bottom: CGFloat in [0, 200, 320, 500] {
      let padding = CameraMath.fitPadding(bottomInset: bottom, leadingInset: 0, wide: false)
      #expect(padding == UIEdgeInsets(top: 130, left: 40, bottom: max(bottom, 320) + 30, right: 40))
    }
  }

  @Test func theWideLayoutMovesTheCentreWestAndLeavesTheBottomAlone() {
    let center = CameraMath.flyCenter(latitude: 43.07, longitude: -89.4, metersPerPoint: 5, bottomInset: 0, leadingInset: 464)
    #expect(center.latitude == 43.07)
    // Half of 464 points at 5 metres a point is 1,160 m: about 0.0142 degrees of longitude at 43 degrees north.
    #expect(abs((-89.4 - center.longitude) - 0.01425) < 0.0005)
    let padding = CameraMath.fitPadding(bottomInset: 0, leadingInset: 464, wide: true)
    #expect(padding.left == 504 && padding.bottom == 40)
  }
}

private enum ServiceDateForTests {
  static let value = ServiceDate(20_261_031)
}
