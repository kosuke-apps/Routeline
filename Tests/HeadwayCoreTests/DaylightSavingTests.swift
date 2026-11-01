import Foundation
import Testing

@testable import HeadwayCore

/// GTFS counts a service day's time from noon minus twelve hours, so on the day the clocks go back 14:00 in the timetable is
/// 14:00 on the wall, and the day's "midnight" is 01:00 on the wall. Adding the seconds to the wall's midnight put every time of
/// 2026-11-01 an hour early (buses looked an hour late all day).
@Suite struct DaylightSavingTests {
  private let chicago = TimeZone(identifier: "America/Chicago")!

  private func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
  }

  @Test func anOrdinaryDayStartsAtMidnight() {
    #expect(ServiceDate(20_261_031).timeOrigin(in: chicago) == utc(2026, 10, 31, 5))  // 00:00 CDT
    #expect(ServiceDate(20_261_031).timeOrigin(in: chicago) == ServiceDate(20_261_031).midnight(in: chicago))
    #expect(ServiceDate(20_261_102).timeOrigin(in: chicago) == utc(2026, 11, 2, 6))  // 00:00 CST
    #expect(ServiceDate(20_261_102).timeOrigin(in: chicago) == ServiceDate(20_261_102).midnight(in: chicago))
  }

  @Test func theDayTheClocksGoBackStartsAnHourAfterMidnight() {
    // 2026-11-01: the wall clock goes from 02:00 CDT back to 01:00 CST.
    let origin = ServiceDate(20_261_101).timeOrigin(in: chicago)
    #expect(origin == utc(2026, 11, 1, 6))  // 00:00 CST, which is 01:00 CDT on the wall
    #expect(origin.timeIntervalSince(ServiceDate(20_261_101).midnight(in: chicago)) == 3_600)
  }

  @Test func theDayTheClocksGoForwardStartsAnHourBeforeMidnight() {
    // 2027-03-14: the wall clock goes from 02:00 CST forward to 03:00 CDT.
    let origin = ServiceDate(20_270_314).timeOrigin(in: chicago)
    #expect(origin == utc(2027, 3, 14, 5))  // 23:00 CST of the 13th
    #expect(origin.timeIntervalSince(ServiceDate(20_270_314).midnight(in: chicago)) == -3_600)
  }

  /// A one-trip timetable on 2026-11-01 (a Sunday): 14:00 and 14:10 at two stops.
  private func scheduleOnTheDayTheClocksGoBack() throws -> Schedule {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("headway-dst-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let files: [String: String] = [
      "agency.txt": "agency_id,agency_name,agency_timezone\n1,Test,America/Chicago\n",
      "routes.txt": "route_id,route_short_name,route_long_name,route_color,route_text_color,route_sort_order\nR,R,Line,FF0000,FFFFFF,1\n",
      "stops.txt": "stop_id,stop_code,stop_name,stop_lat,stop_lon\ns0,0,Stop 0,43.0,-89.40\ns1,1,Stop 1,43.0,-89.38\n",
      "trips.txt": "trip_id,route_id,service_id,trip_headsign,direction_id,shape_id,block_id\nt,R,sun,East,0,sh,b\n",
      "stop_times.txt": "trip_id,arrival_time,departure_time,stop_id,stop_sequence\nt,14:00:00,14:00:00,s0,1\nt,14:10:00,14:10:00,s1,2\n",
      "shapes.txt": "shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence\nsh,43.0,-89.40,1\nsh,43.0,-89.38,2\n",
      "calendar.txt": "service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nsun,0,0,0,0,0,0,1,20261001,20261231\n",
    ]
    for (name, text) in files { try Data(text.utf8).write(to: dir.appendingPathComponent(name)) }
    return try Schedule.load(directory: dir)
  }

  @Test func aTimetableTimeOnTheDayTheClocksGoBackIsTheWallClockTime() throws {
    let schedule = try scheduleOnTheDayTheClocksGoBack()
    // 14:10 on the wall (CST, UTC-6) is 20:10 UTC.
    #expect(schedule.scheduledArrival(tripID: "t", sequence: 2, on: ServiceDate(20_261_101)) == utc(2026, 11, 1, 20, 10))

    let departures = schedule.scheduledDepartures(from: "s0", from: utc(2026, 11, 1, 19), until: utc(2026, 11, 1, 22))
    #expect(departures.map(\.time) == [utc(2026, 11, 1, 20)])  // 14:00 CST, not 13:00
  }

  @Test func aBusAtItsTimetableTimeIsNotAnHourLate() throws {
    let schedule = try scheduleOnTheDayTheClocksGoBack()
    let scheduled = try #require(schedule.scheduledArrival(tripID: "t", sequence: 2, on: ServiceDate(20_261_101)))
    let prediction = TripPrediction(
      entityID: "1", tripID: "t", routeID: "R", directionID: nil, startDate: "", startTime: "", scheduleRelationship: "SCHEDULED",
      vehicleID: "1", timestamp: nil, delay: nil,
      stops: [
        StopPrediction(
          stopID: "s1", sequence: 2, arrival: scheduled.addingTimeInterval(120), arrivalDelay: nil, departure: nil, departureDelay: nil,
          skipped: false)
      ])
    let vehicle = VehicleSample(
      entityID: "1", vehicleID: "1", label: "", tripID: "t", routeID: "R", directionID: nil, startDate: "", latitude: 43,
      longitude: -89.39, bearing: nil, speed: nil, timestamp: nil, currentStopSequence: nil, stopID: "")
    let now = utc(2026, 11, 1, 20, 5)  // 14:05 on the wall
    let delay = ServiceStatusBuilder.delay(of: vehicle, prediction: prediction, schedule: schedule, now: now)
    #expect(delay == 120)
  }

  @Test func theBoardListsTheTripAtItsWallClockTimeToo() throws {
    let schedule = try scheduleOnTheDayTheClocksGoBack()
    let now = utc(2026, 11, 1, 19, 55)  // 13:55 on the wall
    let list = Arrivals.upcoming(schedule: schedule, stopID: "s0", now: now, predictions: [], vehicles: [])
    #expect(list.map(\.scheduled) == [utc(2026, 11, 1, 20)])
    #expect(list.first?.minutes(from: now) == 5)
  }
}
