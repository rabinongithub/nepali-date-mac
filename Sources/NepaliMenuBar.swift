```swift
import SwiftUI
import AppKit
import ServiceManagement
import Foundation

private let nepalTimeZone = TimeZone(identifier: "Asia/Kathmandu")!

private let monthNames = [
    "Baisakh", "Jestha", "Ashadh", "Shrawan",
    "Bhadra", "Ashwin", "Kartik", "Mangsir",
    "Poush", "Magh", "Falgun", "Chaitra"
]

private let nepaliMonthNames = [
    "बैशाख", "जेठ", "असार", "साउन",
    "भदौ", "असोज", "कार्तिक", "मंसिर",
    "पुष", "माघ", "फागुन", "चैत"
]

private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

private let nepaliWeekdays = [
    "आइत", "सोम", "मंगल", "बुध", "बिही", "शुक्र", "शनि"
]

private func nepaliDigits(_ value: String) -> String {
    let digits: [Character: Character] = [
        "0": "०", "1": "१", "2": "२", "3": "३", "4": "४",
        "5": "५", "6": "६", "7": "७", "8": "८", "9": "९"
    ]
    return String(value.map { digits[$0] ?? $0 })
}

private func displayNumber(_ value: Int, nepali: Bool) -> String {
    let number = String(value)
    return nepali ? nepaliDigits(number) : number
}

struct BSYear {
    let year: Int
    let start: Date
    let days: [Int]
    var totalDays: Int { days.reduce(0, +) }
}

struct BSDate {
    let year: Int
    let month: Int
    let day: Int
}

final class NepaliCalendar {
    static let shared = NepaliCalendar()
    let years: [BSYear]

    private init() {
        guard let url = Bundle.main.url(
            forResource: "calendar",
            withExtension: "csv"
        ),
        let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            years = []
            return
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = nepalTimeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        years = content.components(separatedBy: .newlines).compactMap { line in
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, !clean.hasPrefix("#") else { return nil }

            let parts = clean.split(separator: ",").map(String.init)

            guard parts.count == 14,
                  let year = Int(parts[0]),
                  let start = formatter.date(from: parts[1])
            else {
                return nil
            }

            let days = parts.dropFirst(2).compactMap(Int.init)
            guard days.count == 12 else { return nil }

            return BSYear(year: year, start: start, days: days)
        }.sorted { $0.year < $1.year }
    }

    func date(for instant: Date) -> BSDate? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = nepalTimeZone
        let dayStart = cal.startOfDay(for: instant)

        for (i, year) in years.enumerated().reversed() {
            guard dayStart >= year.start else { continue }

            let nextStart = i + 1 < years.count
                ? years[i + 1].start
                : cal.date(
                    byAdding: .day,
                    value: year.totalDays,
                    to: year.start
                )!

            guard dayStart < nextStart else { continue }

            let offset = cal.dateComponents(
                [.day],
                from: year.start,
                to: dayStart
            ).day ?? 0

            var remaining = offset

            for (monthIndex, length) in year.days.enumerated() {
                if remaining < length {
                    return BSDate(
                        year: year.year,
                        month: monthIndex + 1,
                        day: remaining + 1
                    )
                }
                remaining -= length
            }
        }

        return nil
    }

    func gregorianDate(year: Int, month: Int, day: Int) -> Date? {
        guard let yearData = years.first(where: { $0.year == year }),
              (1...12).contains(month),
              day >= 1,
              day <= yearData.days[month - 1]
        else {
            return nil
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = nepalTimeZone

        let before = yearData.days.prefix(month - 1).reduce(0, +) + day - 1
        return cal.date(byAdding: .day, value: before, to: yearData.start)
    }

    func monthLength(year: Int, month: Int) -> Int? {
        guard (1...12).contains(month),
              let yearData = years.first(where: { $0.year == year })
        else {
            return nil
        }

        return yearData.days[month - 1]
    }
}

@main
struct NepaliMenuBarApp: App {
    var body: some Scene {
        MenuBarExtra {
            CalendarPopover()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @AppStorage("displayLanguage") private var displayLanguage = "English"
    @State private var now = Date()

    private var isNepali: Bool {
        displayLanguage == "Nepali"
    }

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .monospacedDigit()
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    now = Date()
                }
            }
    }

    private var label: String {
        guard let date = NepaliCalendar.shared.date(for: now) else {
            return isNepali ? "मिति उपलब्ध छैन" : "BS unavailable"
        }

        let weekdayIndex = weekdayIndexForToday()
        let weekday = isNepali
            ? ["आइतबार", "सोमबार", "मंगलबार", "बुधबार",
               "बिहीबार", "शुक्रबार", "शनिबार"][weekdayIndex]
            : ["Sunday", "Monday", "Tuesday", "Wednesday",
               "Thursday", "Friday", "Saturday"][weekdayIndex]

        let day = displayNumber(date.day, nepali: isNepali)
        let year = displayNumber(date.year, nepali: isNepali)
        let month = isNepali
            ? nepaliMonthNames[date.month - 1]
            : monthNames[date.month - 1]

        return "\(weekday), \(day) \(month), \(year)"
    }

    private func weekdayIndexForToday() -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = nepalTimeZone
        return cal.component(.weekday, from: now) - 1
    }
}

struct CalendarPopover: View {
    @AppStorage("displayLanguage") private var displayLanguage = "English"

    @State private var now = Date()
    @State private var shownYear = 2083
    @State private var shownMonth = 7
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var message: String?

    private var isNepali: Bool {
        displayLanguage == "Nepali"
    }

    private var bsToday: BSDate? {
        NepaliCalendar.shared.date(for: now)
    }

    private var currentMonthNames: [String] {
        isNepali ? nepaliMonthNames : monthNames
    }

    private var currentWeekdays: [String] {
        isNepali ? nepaliWeekdays : weekdays
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = nepalTimeZone
        formatter.dateFormat = "HH:mm:ss"

        let value = formatter.string(from: now)
        return isNepali
            ? "\(nepaliDigits(value)) नेपाली समय"
            : "\(value) NPT"
    }

    private var adText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isNepali ? "ne_NP" : "en_US")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = nepalTimeZone
        formatter.dateFormat = "EEEE, d MMMM yyyy"

        let value = formatter.string(from: now)
        return isNepali ? nepaliDigits(value) : value
    }

    private var gridDays: [Int?] {
        guard let first = NepaliCalendar.shared.gregorianDate(
            year: shownYear,
            month: shownMonth,
            day: 1
        ),
        let length = NepaliCalendar.shared.monthLength(
            year: shownYear,
            month: shownMonth
        )
        else {
            return []
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = nepalTimeZone
        let weekday = cal.component(.weekday, from: first) - 1

        return Array(repeating: nil, count: weekday)
            + (1...length).map { Optional($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isNepali ? "नेपाली पात्रो" : "NEPALI CALENDAR")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .tracking(isNepali ? 0 : 1)

                    if let date = bsToday {
                        Text(
                            "\(displayNumber(date.day, nepali: isNepali)) " +
                            "\(currentMonthNames[date.month - 1]) " +
                            "\(displayNumber(date.year, nepali: isNepali))"
                        )
                        .font(.title2.bold())
                    } else {
                        Text(isNepali ? "मिति उपलब्ध छैन" : "Date unavailable")
                            .font(.headline)
                    }

                    Text(adText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(timeText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button {
                    moveMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(
                    "\(currentMonthNames[shownMonth - 1]) " +
                    "\(displayNumber(shownYear, nepali: isNepali))"
                )
                .font(.headline)

                Spacer()

                Button {
                    moveMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 2),
                    count: 7
                ),
                spacing: 5
            ) {
                ForEach(Array(currentWeekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let isToday = bsToday?.year == shownYear
                            && bsToday?.month == shownMonth
                            && bsToday?.day == day

                        Text(displayNumber(day, nepali: isNepali))
                            .font(
                                .system(
                                    size: 12,
                                    weight: isToday ? .bold : .regular
                                )
                            )
                            .frame(maxWidth: .infinity, minHeight: 25)
                            .background(
                                isToday ? Color.accentColor : Color.clear
                            )
                            .foregroundStyle(
                                isToday ? Color.white : Color.primary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Text(" ")
                            .frame(maxWidth: .infinity, minHeight: 25)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(isNepali ? "भाषा / Language" : "Language / भाषा")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(
                    isNepali ? "भाषा" : "Language",
                    selection: $displayLanguage
                ) {
                    Text("English").tag("English")
                    Text("नेपाली").tag("Nepali")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Toggle(
                isNepali ? "लगइन हुँदा खोल्नुहोस्" : "Launch at login",
                isOn: $launchAtLogin
            )
            .toggleStyle(.switch)
            .onChange(of: launchAtLogin) { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    message = nil
                } catch {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                    message = isNepali
                        ? "सेटिङ परिवर्तन गर्न सकिएन: \(error.localizedDescription)"
                        : "Could not update login setting: \(error.localizedDescription)"
                }
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Text(
                    isNepali
                        ? "अफलाइन • नेपाल मानक समय"
                        : "Offline • Nepal Standard Time"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer()

                Button(isNepali ? "बन्द गर्नुहोस्" : "Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 330)
        .onAppear {
            now = Date()
            if let date = NepaliCalendar.shared.date(for: now) {
                shownYear = date.year
                shownMonth = date.month
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                now = Date()
            }
        }
    }

    private func moveMonth(_ delta: Int) {
        var month = shownMonth + delta
        var year = shownYear

        if month < 1 {
            month = 12
            year -= 1
        }

        if month > 12 {
            month = 1
            year += 1
        }

        guard NepaliCalendar.shared.monthLength(
            year: year,
            month: month
        ) != nil else {
            message = isNepali
                ? "पात्रोको डेटा वि.सं. २०८०–२०९० सम्म मात्र उपलब्ध छ।"
                : "Calendar data bundled for BS 2080–2090 only."
            return
        }

        shownMonth = month
        shownYear = year
        message = nil
    }
}
```
