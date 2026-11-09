import Foundation
import Network

/// Whether the phone is on a connection that costs the rider data: mobile data or a personal hotspot (`isExpensive`), or
/// any connection while Low Data Mode is on (`isConstrained`). Read by the code that decides how often to fetch. Also says
/// whether there is a connection at all (`isOnline`), which the status line over the map shows as "Offline".
final class NetworkStatus: @unchecked Sendable {
  static let shared = NetworkStatus()

  private let monitor = NWPathMonitor()
  private let lock = NSLock()
  private var expensive = false
  private var constrained = false
  private var online = true
  private var started = false
  private var pathChanged: (@Sendable (Bool) -> Void)?

  var isExpensive: Bool { lock.withLock { expensive } }
  var isConstrained: Bool { lock.withLock { constrained } }
  /// False when the system says no network can be reached (Airplane Mode, no signal, Wi-Fi without a route out). True until the
  /// first report, so that a slow start never shows "Offline".
  var isOnline: Bool { lock.withLock { online } }

  /// Called on a background queue with the new state each time the connection comes or goes. Set before `start()`.
  func onPathChange(_ handler: @escaping @Sendable (Bool) -> Void) {
    lock.withLock { pathChanged = handler }
  }

  /// Starts watching the connection; harmless to call again.
  func start() {
    let already = lock.withLock { () -> Bool in
      defer { started = true }
      return started
    }
    guard !already else { return }
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      let handler = self.lock.withLock { () -> (@Sendable (Bool) -> Void)? in
        self.expensive = path.isExpensive
        self.constrained = path.isConstrained
        self.online = path.status == .satisfied
        return self.pathChanged
      }
      handler?(path.status == .satisfied)
    }
    monitor.start(queue: DispatchQueue(label: "dev.kosuke.headway.network"))
  }

  /// True on mobile data, a personal hotspot or in Low Data Mode: where the rider's data choices for "mobile" apply.
  var isMetered: Bool { isExpensive || isConstrained }

  /// How much longer than usual to wait between large downloads: 1 on Wi-Fi, 2 on mobile data, 4 in Low Data Mode.
  /// `saving` is the rider's "Save mobile data" choice; without it the connection is treated as free.
  func slowdown(saving: Bool) -> Double {
    guard saving else { return 1 }
    if isConstrained { return 4 }
    return isExpensive ? 2 : 1
  }

  /// True when a failed request says the phone could not reach the network at all (no connection, dropped, no DNS), as opposed
  /// to the city's server answering badly or slowly. A time-out is left out on purpose: the server may be the slow one.
  static func isConnectivityError(_ error: Error) -> Bool {
    guard let code = (error as? URLError)?.code else { return false }
    switch code {
    case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
      return true
    default:
      return false
    }
  }
}
