import Foundation

struct WeeklySchedule: Codable, Equatable {
    var weekdays: Set<Int>
    var startMinute: Int
    var endMinute: Int

    enum ValidationError: LocalizedError {
        case weekdays, time, overnight
        var errorDescription: String? {
            switch self {
            case .weekdays: return "曜日を1つ以上選んでください。"
            case .time: return "開始・終了時刻を確認してください。"
            case .overnight: return "終了時刻は開始時刻より後にしてください。日付をまたぐ場合は、ルールを分けて設定してください。"
            }
        }
    }

    func validate() throws {
        guard !weekdays.isEmpty, weekdays.isSubset(of: Set(1...7)) else { throw ValidationError.weekdays }
        guard (0..<1440).contains(startMinute), (0..<1440).contains(endMinute) else { throw ValidationError.time }
        guard endMinute > startMinute else { throw ValidationError.overnight }
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let day = parts.weekday, let hour = parts.hour, let minute = parts.minute else { return false }
        let time = hour * 60 + minute
        return weekdays.contains(day) && time >= startMinute && time < endMinute
    }

    func nextBoundary(after date: Date, calendar: Calendar = .current) -> Date? {
        weekdays.flatMap { day in
            [startMinute, endMinute].compactMap { minute in
                calendar.nextDate(after: date,
                                  matching: DateComponents(hour: minute / 60, minute: minute % 60,
                                                           second: 0, weekday: day),
                                  matchingPolicy: .nextTime, repeatedTimePolicy: .first)
            }
        }.min()
    }

    // DeviceActivity intervals must be at least 15 minutes. Short rules use a
    // 16-minute interval with an end warning at the rule's actual end time.
    var monitoringEndMinute: Int {
        endMinute - startMinute < 15 ? (startMinute + 16) % 1440 : endMinute
    }

    var endWarningMinutes: Int? {
        endMinute - startMinute < 15 ? 16 - (endMinute - startMinute) : nil
    }
}

struct ScheduledApplications<Token: Hashable> {
    var schedule: WeeklySchedule
    var applications: Set<Token>
    var enabled: Bool
}

enum RuleEvaluator {
    static func lockedApplications<Token: Hashable>(from rules: [ScheduledApplications<Token>],
                                                    at date: Date, calendar: Calendar = .current) -> Set<Token> {
        rules.reduce(into: Set<Token>()) { result, rule in
            if rule.enabled && rule.schedule.contains(date, calendar: calendar) {
                result.formUnion(rule.applications)
            }
        }
    }
}
