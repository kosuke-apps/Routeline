import Foundation
import Testing

@testable import Headway

@Suite struct NetworkStatusTests {
  @Test func nothingIsSlowedWhenTheRiderDoesNotSaveData() {
    // On Wi-Fi (the test machine's connection) the factor is 1; with saving off it is 1 whatever the connection.
    #expect(NetworkStatus.shared.slowdown(saving: false) == 1)
  }

  @Test func theFactorIsOneTwoOrFour() {
    #expect([1.0, 2.0, 4.0].contains(NetworkStatus.shared.slowdown(saving: true)))
  }
}

@Suite struct OfflineWordingTests {
  /// The wording is localised, so these tests check which cases read the same and which differ, and that the numbers appear.
  @Test func offlineIsNeverWordedLikeADelay() {
    let offlineNoBuses = LiveStatusText.pill(age: nil, buses: 0, offline: true, failing: true, late: true)
    let offlineWithAge = LiveStatusText.pill(age: 125, buses: 90, offline: true, failing: true, late: true)
    let delayed = LiveStatusText.pill(age: 125, buses: 90, offline: false, failing: false, late: true)
    let failing = LiveStatusText.pill(age: 125, buses: 90, offline: false, failing: true, late: true)
    let connecting = LiveStatusText.pill(age: nil, buses: 0, offline: false, failing: false, late: false)
    let live = LiveStatusText.pill(age: 20, buses: 90, offline: false, failing: false, late: false)
    #expect(Set([offlineNoBuses, offlineWithAge, delayed, failing, connecting, live]).count == 6)
    #expect(offlineWithAge.contains("125"))
    #expect(live.contains("90") && live.contains("20"))
    // Offline wins over a failure and a delay, and says so before any other state does (also when no bus has been seen).
    #expect(offlineNoBuses != connecting)
    #expect(LiveStatusText.pill(age: 125, buses: 90, offline: true, failing: false, late: false) == offlineWithAge)
  }

  @Test func onlyLostConnectionsCountAsOffline() {
    for code in [URLError.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .dnsLookupFailed, .dataNotAllowed] {
      #expect(NetworkStatus.isConnectivityError(URLError(code)))
    }
    // The city's server may be the slow one, or answering with an error: not "offline".
    #expect(!NetworkStatus.isConnectivityError(URLError(.timedOut)))
    #expect(!NetworkStatus.isConnectivityError(URLError(.badServerResponse)))
    #expect(!NetworkStatus.isConnectivityError(CancellationError()))
  }
}
