import Foundation

enum ResetTimeFormatter {
    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 2
        f.zeroFormattingBehavior = .dropAll
        return f
    }()

    /// 팝오버용 한 줄. "Resets in 2h 34m" / "2시간 34분 후 초기화"
    static func resetLine(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return String(localized: "Resets in —") }
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return String(localized: "Resets soon") }
        let duration = durationFormatter.string(from: interval) ?? ""
        return String(localized: "Resets in \(duration)")
    }

    /// 메뉴바용 짧은 형식. "1h 20m" / "1시간 20분". 1분 미만이면 "soon" 류.
    static func compact(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return String(localized: "Resets soon") }
        if interval < 60 { return durationFormatter.string(from: 60) ?? "" }
        return durationFormatter.string(from: interval) ?? ""
    }
}
