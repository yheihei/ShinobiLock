import Foundation
import Testing
@testable import ShinobiLockCore

private let testCalendar: Calendar = {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
    return value
}()

private func date(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
    testCalendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute, second: second))!
}

@Test func scheduleStartsInclusivelyAndEndsExclusively() {
    let schedule = WeeklySchedule(weekdays: [7], startMinute: 600, endMinute: 660)
    #expect(!schedule.contains(date(12, 9, 59, 59), calendar: testCalendar))
    #expect(schedule.contains(date(12, 10, 0), calendar: testCalendar))
    #expect(schedule.contains(date(12, 10, 59, 59), calendar: testCalendar))
    #expect(!schedule.contains(date(12, 11, 0), calendar: testCalendar))
    #expect(!schedule.contains(date(13, 10, 30), calendar: testCalendar))
}

@Test func overlappingRulesKeepSharedApplicationLocked() {
    let first = ScheduledApplications(schedule: WeeklySchedule(weekdays: [7], startMinute: 600, endMinute: 660),
                                      applications: Set(["chat", "video"]), enabled: true)
    let second = ScheduledApplications(schedule: WeeklySchedule(weekdays: [7], startMinute: 630, endMinute: 720),
                                       applications: Set(["chat"]), enabled: true)
    #expect(RuleEvaluator.lockedApplications(from: [first, second], at: date(12, 10, 45), calendar: testCalendar) == ["chat", "video"])
    #expect(RuleEvaluator.lockedApplications(from: [first, second], at: date(12, 11, 0), calendar: testCalendar) == ["chat"])
    #expect(RuleEvaluator.lockedApplications(from: [first, second], at: date(12, 12, 0), calendar: testCalendar).isEmpty)
    var disabled = second
    disabled.enabled = false
    #expect(RuleEvaluator.lockedApplications(from: [first, disabled], at: date(12, 11, 0), calendar: testCalendar).isEmpty)
}

@Test func scheduleValidationRejectsMissingDaysAndOvernightRanges() {
    #expect(throws: WeeklySchedule.ValidationError.self) { try WeeklySchedule(weekdays: [], startMinute: 600, endMinute: 660).validate() }
    #expect(throws: WeeklySchedule.ValidationError.self) { try WeeklySchedule(weekdays: [0], startMinute: 600, endMinute: 660).validate() }
    #expect(throws: WeeklySchedule.ValidationError.self) { try WeeklySchedule(weekdays: [7], startMinute: 600, endMinute: 600).validate() }
    #expect(throws: WeeklySchedule.ValidationError.self) { try WeeklySchedule(weekdays: [7], startMinute: 1380, endMinute: 60).validate() }
    #expect(throws: WeeklySchedule.ValidationError.self) { try WeeklySchedule(weekdays: [7], startMinute: -1, endMinute: 60).validate() }
}

@Test func nextBoundaryFollowsSelectedWeekdayAcrossWeek() {
    let schedule = WeeklySchedule(weekdays: [7], startMinute: 600, endMinute: 660)
    #expect(schedule.nextBoundary(after: date(12, 10, 30), calendar: testCalendar) == date(12, 11, 0))
    #expect(schedule.nextBoundary(after: date(12, 11, 0), calendar: testCalendar) == date(19, 10, 0))
}

@Test func timeZoneChangesUseLocalWallClock() {
    let schedule = WeeklySchedule(weekdays: [7], startMinute: 600, endMinute: 660)
    let instant = date(12, 10, 30)
    var utc = testCalendar
    utc.timeZone = TimeZone(secondsFromGMT: 0)!
    #expect(schedule.contains(instant, calendar: testCalendar))
    #expect(!schedule.contains(instant, calendar: utc))
}

@Test func shortMonitoringWindowKeepsRequestedWarningAcrossMidnight() throws {
    let schedule = WeeklySchedule(weekdays: [7], startMinute: 1430, endMinute: 1439)
    try schedule.validate()
    #expect(schedule.monitoringEndMinute == 6)
    #expect(schedule.endWarningMinutes == 7)
    let regular = WeeklySchedule(weekdays: [7], startMinute: 600, endMinute: 615)
    #expect(regular.monitoringEndMinute == 615)
    #expect(regular.endWarningMinutes == nil)
}
