import Foundation
import Testing

@testable import RoutelineCore

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
    try schedule(first: "14:00:00", second: "14:10:00")
  }

  /// A one-trip timetable between two stops that runs on Sundays (and on Saturdays when `saturday` is set), all of 2026 and 2027.
  private func schedule(first: String, second: String, saturday: Bool = false) throws -> Schedule {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("routeline-dst-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let files: [String: String] = [
      "agency.txt": "agency_id,agency_name,agency_timezone\n1,Test,America/Chicago\n",
      "routes.txt": "route_id,route_short_name,route_long_name,route_color,route_text_color,route_sort_order\nR,R,Line,FF0000,FFFFFF,1\n",
      "stops.txt": "stop_id,stop_code,stop_name,stop_lat,stop_lon\ns0,0,Stop 0,43.0,-89.40\ns1,1,Stop 1,43.0,-89.38\n",
      "trips.txt": "trip_id,route_id,service_id,trip_headsign,direction_id,shape_id,block_id\nt,R,sun,East,0,sh,b\n",
      "stop_times.txt": "trip_id,arrival_time,departure_time,stop_id,stop_sequence\nt,\(first),\(first),s0,1\nt,\(second),\(second),s1,2\n",
      "shapes.txt": "shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence\nsh,43.0,-89.40,1\nsh,43.0,-89.38,2\n",
      "calendar.txt": "service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\nsun,0,0,0,0,0,\(saturday ? 1 : 0),1,20260101,20271231\n",
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

  // MARK: The day the clocks go forward, and times past midnight

  @Test func aTimetableTimeOnTheDayTheClocksGoForwardIsTheWallClockTime() throws {
    let schedule = try schedule(first: "08:00:00", second: "08:10:00")
    // 2027-03-14 08:10 on the wall is CDT (UTC-5): 13:10 UTC.
    #expect(schedule.scheduledArrival(tripID: "t", sequence: 2, on: ServiceDate(20_270_314)) == utc(2027, 3, 14, 13, 10))
  }

  @Test func aTimePastMidnightIsTheWallClockTimeOfTheNextMorning() throws {
    let schedule = try schedule(first: "24:50:00", second: "25:10:00", saturday: true)
    // Saturday 2027-03-13, before the clocks go forward at 02:00: 01:10 CST (UTC-6).
    #expect(schedule.scheduledArrival(tripID: "t", sequence: 2, on: ServiceDate(20_270_313)) == utc(2027, 3, 14, 7, 10))
    // Sunday 2027-03-14 itself: the next morning's 01:10 is CDT (UTC-5).
    #expect(schedule.scheduledArrival(tripID: "t", sequence: 2, on: ServiceDate(20_270_314)) == utc(2027, 3, 15, 6, 10))
    // Sunday 2026-11-01, the day the clocks go back: the next morning's 01:10 is CST (UTC-6).
    #expect(schedule.scheduledArrival(tripID: "t", sequence: 2, on: ServiceDate(20_261_101)) == utc(2026, 11, 2, 7, 10))
  }

  @Test func aTripBeforeOneOClockOnTheDayTheClocksGoForwardIsFoundTheEveningBefore() throws {
    // Its date starts at 23:00 on the wall of the evening before, so 00:30 of Sunday 2027-03-14 is 23:30 CST on Saturday.
    let schedule = try schedule(first: "00:30:00", second: "00:40:00")
    let moment = utc(2027, 3, 14, 5, 35)  // 23:35 CST on Saturday the 13th
    let departures = schedule.scheduledDepartures(from: "s0", from: utc(2027, 3, 14, 5), until: utc(2027, 3, 14, 5, 59))
    #expect(departures.map(\.time) == [utc(2027, 3, 14, 5, 30)])
    #expect(schedule.scheduledTrips(at: moment).map(\.serviceDate.value) == [20_270_314])
    #expect(schedule.serviceDate(of: "t", near: moment)?.value == 20_270_314)
  }

  @Test func todayIsTheDateOnTheWall() {
    #expect(ServiceDate(utc(2027, 3, 14, 5, 30), in: chicago).value == 20_270_313)  // 23:30 CST on Saturday
    #expect(DayType(ServiceDate(utc(2027, 3, 14, 5, 30), in: chicago), in: chicago) == .saturday)
    #expect(ServiceDate(utc(2027, 3, 14, 8, 0), in: chicago).value == 20_270_314)  // 03:00 CDT, just after the jump
    #expect(DayType(ServiceDate(utc(2027, 3, 14, 8, 0), in: chicago), in: chicago) == .sunday)
    #expect(ServiceDate(utc(2026, 11, 1, 6, 30), in: chicago).value == 20_261_101)  // 01:30 CDT, the first time round
    #expect(ServiceDate(utc(2026, 11, 1, 7, 30), in: chicago).value == 20_261_101)  // 01:30 CST, the second time round
    #expect(ServiceDate(utc(2026, 11, 2, 5, 59), in: chicago).value == 20_261_101)  // 23:59 CST
  }

  @Test func datesStepByOneAcrossBothChanges() {
    func run(from first: Int) -> [Int] {
      var date = ServiceDate(first)
      var values = [date.value]
      for _ in 0..<4 {
        date = date.adding(days: 1, in: chicago)
        values.append(date.value)
      }
      return values
    }
    #expect(run(from: 20_270_312) == [20_270_312, 20_270_313, 20_270_314, 20_270_315, 20_270_316])
    #expect(run(from: 20_261_030) == [20_261_030, 20_261_031, 20_261_101, 20_261_102, 20_261_103])
    #expect(ServiceDate(20_270_315).adding(days: -2, in: chicago).value == 20_270_313)
    #expect(ServiceDate(20_261_102).adding(days: -2, in: chicago).value == 20_261_031)
  }
}
