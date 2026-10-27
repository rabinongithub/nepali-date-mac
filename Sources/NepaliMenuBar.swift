import SwiftUI
import AppKit
import ServiceManagement
import Foundation

private let nepalTimeZone = TimeZone(identifier: "Asia/Kathmandu")!
private let monthNames = ["Baisakh", "Jestha", "Ashadh", "Shrawan", "Bhadra", "Ashwin",
                          "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra"]
private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

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
        guard let url = Bundle.main.url(forResource: "calendar", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            years = []; return
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = nepalTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        years = content.components(separatedBy: .newlines).compactMap { line in
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, !clean.hasPrefix("#") else { return nil }
            let p = clean.split(separator: ",").map(String.init)
            guard p.count == 14, let year = Int(p[0]), let start = formatter.date(from: p[1]) else { return nil }
            let days = p.dropFirst(2).compactMap(Int.init)
            guard days.count == 12 else { return nil }
            return BSYear(year: year, start: start, days: days)
        }.sorted { $0.year < $1.year }
    }

    func date(for instant: Date) -> BSDate? {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = nepalTimeZone
        let dayStart = cal.startOfDay(for: instant)
        for (i, y) in years.enumerated().reversed() {
            guard dayStart >= y.start else { continue }
            let nextStart = i + 1 < years.count ? years[i + 1].start : cal.date(byAdding: .day, value: y.totalDays, to: y.start)!
            guard dayStart < nextStart else { continue }
            let offset = cal.dateComponents([.day], from: y.start, to: dayStart).day ?? 0
            var remaining = offset
            for (m, length) in y.days.enumerated() {
                if remaining < length { return BSDate(year: y.year, month: m + 1, day: remaining + 1) }
                remaining -= length
            }
        }
        return nil
    }

    func gregorianDate(year: Int, month: Int, day: Int) -> Date? {
        guard let y = years.first(where: { $0.year == year }),
              (1...12).contains(month), day >= 1, day <= y.days[month - 1] else { return nil }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = nepalTimeZone
        let before = y.days.prefix(month - 1).reduce(0, +) + day - 1
        return cal.date(byAdding: .day, value: before, to: y.start)
    }

    func monthLength(year: Int, month: Int) -> Int? {
        guard (1...12).contains(month), let y = years.first(where: {$0.year == year}) else { return nil }
        return y.days[month - 1]
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
    @State private var now = Date()
    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .monospacedDigit()
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    now = Date()
                }
            }
    }
    private var label: String {
        guard let bs = NepaliCalendar.shared.date(for: now) else { return "BS unavailable" }
        return "\(bs.day) \(monthNames[bs.month - 1])"
    }
}

struct CalendarPopover: View {
    @State private var now = Date()
    @State private var shownYear = 2083
    @State private var shownMonth = 7
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var message: String?

    private var bsToday: BSDate? { NepaliCalendar.shared.date(for: now) }
    private var timeText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = nepalTimeZone; f.dateFormat = "HH:mm:ss"
        return f.string(from: now) + " NPT"
    }
    private var adText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = nepalTimeZone; f.dateFormat = "EEE, d MMM yyyy"
        return f.string(from: now)
    }
    private var gridDays: [Int?] {
        guard let first = NepaliCalendar.shared.gregorianDate(year: shownYear, month: shownMonth, day: 1),
              let length = NepaliCalendar.shared.monthLength(year: shownYear, month: shownMonth) else { return [] }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = nepalTimeZone
        let weekday = cal.component(.weekday, from: first) - 1
        return Array(repeating: nil, count: weekday) + (1...length).map { Optional($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEPALI CALENDAR").font(.caption2).foregroundStyle(.secondary).tracking(1)
                    if let d = bsToday {
                        Text("\(d.day) \(monthNames[d.month - 1]) \(d.year)")
                            .font(.title2.bold())
                    } else {
                        Text("Date outside bundled range").font(.headline)
                    }
                    Text(adText).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text(timeText).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Spacer()
                Text("\(monthNames[shownMonth - 1]) \(shownYear)").font(.headline)
                Spacer()
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 5) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day).font(.caption2.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let isToday = bsToday?.year == shownYear && bsToday?.month == shownMonth && bsToday?.day == day
                        Text("\(day)")
                            .font(.system(size: 12, weight: isToday ? .bold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 25)
                            .background(isToday ? Color.accentColor : Color.clear)
                            .foregroundStyle(isToday ? Color.white : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Text(" ").frame(maxWidth: .infinity, minHeight: 25)
                    }
                }
            }
            Divider()
            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                        message = nil
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                        message = "Could not update login setting: \(error.localizedDescription)"
                    }
                }
            if let message { Text(message).font(.caption).foregroundStyle(.red) }
            HStack {
                Text("Offline • Nepal Standard Time").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 310)
        .onAppear {
            now = Date()
            if let d = NepaliCalendar.shared.date(for: now) { shownYear = d.year; shownMonth = d.month }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                now = Date()
            }
        }
    }

    private func moveMonth(_ delta: Int) {
        var m = shownMonth + delta
        var y = shownYear
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        guard NepaliCalendar.shared.monthLength(year: y, month: m) != nil else {
            message = "Calendar data bundled for BS 2080–2090 only."
            return
        }
        shownMonth = m; shownYear = y; message = nil
    }
}
