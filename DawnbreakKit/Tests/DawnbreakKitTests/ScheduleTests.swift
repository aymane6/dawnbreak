import Foundation
import Testing
@testable import DawnbreakKit

/// A fixed calendar so none of these assertions depend on the machine's region.
private func calendar(_ identifier: String = "Europe/Paris", firstWeekday: Int = 2) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: identifier)!
    c.firstWeekday = firstWeekday
    return c
}

private func date(_ string: String, in zone: String = "Europe/Paris") -> Date {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = TimeZone(identifier: zone)!
    return formatter.date(from: string)!
}

@Suite("Alarm scheduling")
struct ScheduleTests {

    @Test("A one-shot alarm fires later today when the time has not passed")
    func oneShotToday() {
        let alarm = AlarmDraft(hour: 7, minute: 30)
        let now = date("2026-03-10 06:00:00")
        let next = alarm.nextFireDate(after: now, calendar: calendar())
        #expect(next == date("2026-03-10 07:30:00"))
    }

    @Test("A one-shot alarm rolls to tomorrow once the time has passed")
    func oneShotTomorrow() {
        let alarm = AlarmDraft(hour: 7, minute: 30)
        let now = date("2026-03-10 07:30:01")
        #expect(alarm.nextFireDate(after: now, calendar: calendar()) == date("2026-03-11 07:30:00"))
    }

    @Test("A disabled alarm has no next fire date")
    func disabled() {
        let alarm = AlarmDraft(hour: 7, minute: 0, isEnabled: false)
        #expect(alarm.nextFireDate(after: date("2026-03-10 06:00:00"), calendar: calendar()) == nil)
    }

    @Test("A weekday alarm skips the weekend")
    func weekdaysSkipWeekend() {
        let alarm = AlarmDraft(hour: 6, minute: 45, repeatDays: .weekdays)
        // 2026-03-13 is a Friday; 08:00 is past the alarm, so the next one is Monday.
        let next = alarm.nextFireDate(after: date("2026-03-13 08:00:00"), calendar: calendar())
        #expect(next == date("2026-03-16 06:45:00"))
    }

    @Test("A repeating alarm picks the soonest of its days")
    func soonestOfSeveral() {
        let alarm = AlarmDraft(hour: 9, minute: 0, repeatDays: [.wednesday, .sunday])
        // Monday 2026-03-09 → Wednesday is sooner than Sunday.
        #expect(alarm.nextFireDate(after: date("2026-03-09 10:00:00"), calendar: calendar()) == date("2026-03-11 09:00:00"))
    }

    /// The spring-forward morning: in Europe/Paris on 2026-03-29 the clock jumps 02:00 →
    /// 03:00, so 02:30 does not exist. The alarm must land on a real instant rather than
    /// return nil and silently never ring.
    @Test("An alarm inside the spring-forward gap still resolves")
    func springForwardGap() throws {
        let alarm = AlarmDraft(hour: 2, minute: 30, repeatDays: .everyDay)
        let next = try #require(alarm.nextFireDate(after: date("2026-03-29 01:00:00"), calendar: calendar()))
        // Whatever the calendar chooses, it must be a real future instant, and within a day.
        #expect(next > date("2026-03-29 01:00:00"))
        #expect(next < date("2026-03-30 12:00:00"))
    }

    /// The autumn morning where 02:30 happens twice. Either instant is defensible; ringing
    /// zero times is not.
    @Test("An alarm inside the fall-back repeat resolves once")
    func fallBackRepeat() throws {
        let alarm = AlarmDraft(hour: 2, minute: 30, repeatDays: .everyDay)
        let next = try #require(alarm.nextFireDate(after: date("2026-10-25 00:30:00"), calendar: calendar()))
        #expect(next > date("2026-10-25 00:30:00"))
    }

    @Test("Wall-clock time does not move when the phone changes timezone")
    func timezoneIndependent() throws {
        let alarm = AlarmDraft(hour: 7, minute: 0, repeatDays: .everyDay)
        let paris = try #require(alarm.nextFireDate(after: date("2026-03-10 06:00:00"), calendar: calendar("Europe/Paris")))
        let tokyo = try #require(alarm.nextFireDate(after: date("2026-03-10 06:00:00", in: "Asia/Tokyo"), calendar: calendar("Asia/Tokyo")))
        // Two different instants, both 07:00 local. That is the whole point of storing
        // hour+minute rather than a Date.
        var parisCal = calendar("Europe/Paris"); parisCal.timeZone = TimeZone(identifier: "Europe/Paris")!
        var tokyoCal = calendar("Asia/Tokyo"); tokyoCal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        #expect(parisCal.component(.hour, from: paris) == 7)
        #expect(tokyoCal.component(.hour, from: tokyo) == 7)
    }

    @Test("Out-of-range times are clamped rather than stored")
    func clamping() {
        #expect(AlarmDraft(hour: 99, minute: -4).hour == 23)
        #expect(AlarmDraft(hour: 99, minute: -4).minute == 0)
        #expect(AlarmDraft(volume: 5).volume == 1)
        #expect(AlarmDraft(gentleWakeSeconds: 9999).gentleWakeSeconds == 300)
    }

    @Test("Snooze minutes are clamped to something a human would choose")
    func snoozeClamping() {
        #expect(AlarmDraft.SnoozePolicy(minutes: 0).minutes == 1)
        #expect(AlarmDraft.SnoozePolicy(minutes: 90).minutes == 30)
    }
}

@Suite("Weekday ordering")
struct WeekdayTests {

    @Test("Monday-first regions start the picker on Monday")
    func mondayFirst() {
        #expect(Weekday.ordered(firstWeekday: 2).first == .monday)
        #expect(Weekday.ordered(firstWeekday: 2).last == .sunday)
    }

    @Test("Sunday-first regions start the picker on Sunday")
    func sundayFirst() {
        let order = Weekday.ordered(firstWeekday: 1)
        #expect(order.first == .sunday)
        #expect(order.dropFirst().first == .monday)
        #expect(order.count == 7)
    }

    @Test("Saturday-first regions are supported too")
    func saturdayFirst() {
        // firstWeekday 7 = Saturday, the default across much of the Middle East.
        #expect(Weekday.ordered(firstWeekday: 7).first == .saturday)
    }

    @Test("Round-trips through Calendar's Sunday-is-1 numbering")
    func calendarNumbering() {
        for day in Weekday.allCases {
            #expect(Weekday(calendarWeekday: day.calendarWeekday) == day)
        }
        #expect(Weekday.sunday.calendarWeekday == 1)
        #expect(Weekday.monday.calendarWeekday == 2)
        #expect(Weekday(calendarWeekday: 8) == nil)
    }

    @Test("Common day sets get their own summary label")
    func summaries() {
        #expect(Set<Weekday>().repeatSummaryKey == "repeat.never")
        #expect(Set<Weekday>.everyDay.repeatSummaryKey == "repeat.everyDay")
        #expect(Set<Weekday>.weekdays.repeatSummaryKey == "repeat.weekdays")
        #expect(Set<Weekday>.weekend.repeatSummaryKey == "repeat.weekends")
        #expect(Set<Weekday>([.monday, .thursday]).repeatSummaryKey == nil)
    }
}
