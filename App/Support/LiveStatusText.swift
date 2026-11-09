import Foundation

/// The words of the status line over the map. Kept apart from the view so that the cases can be tested: the line must say
/// "Offline" whenever the phone has no connection, and not read like a feed that is merely late.
enum LiveStatusText {
  /// - Parameters:
  ///   - age: how old the positions on screen are (nil before the first bus has been seen).
  ///   - buses: how many buses are on screen.
  ///   - offline: the phone has no connection (`AppModel.isOffline`).
  ///   - failing: the last request failed for another reason, such as the city's server not answering.
  ///   - late: positions are old enough to be called delayed.
  static func pill(age: TimeInterval?, buses: Int, offline: Bool, failing: Bool, late: Bool) -> String {
    if offline {
      guard let age else { return L10n.string("Offline") }
      return L10n.string("Offline · positions \(Int(age.rounded())) s old")
    }
    guard let age else { return L10n.string("Connecting…") }
    let seconds = Int(age.rounded())
    if failing { return L10n.string("City feed not answering · positions \(seconds) s old") }
    if late { return L10n.string("Delayed · positions \(seconds) s old") }
    return L10n.string("Live · \(buses) buses · positions \(seconds) s old")
  }
}
