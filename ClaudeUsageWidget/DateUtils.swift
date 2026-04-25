//
//  DateUtils.swift
//  ClaudeUsageWidget
//
//  Created by 윤경렬 on 4/19/26.
//

import Foundation

enum ResetTimeFormatter {
    /// "2시간 34분 남음" / "3일 후 초기화" 같은 표현
    static func timeUntil(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "—" }
        
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return "곧 초기화" }
        
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let days = hours / 24
        
        if days >= 1 {
            let remainingHours = hours % 24
            return remainingHours > 0
                ? "\(days)일 \(remainingHours)시간 후"
                : "\(days)일 후"
        } else if hours >= 1 {
            let remainingMinutes = minutes % 60
            return "\(hours)시간 \(remainingMinutes)분 후"
        } else {
            return "\(minutes)분 후"
        }
    }
    
    static func timeUntilEnglish(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "Resets in —" }
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return "Resets soon" }
        let minutes = Int(interval / 60)
        let hours   = minutes / 60
        let days    = hours / 24
        if days >= 1 {
            let h = hours % 24
            return h > 0 ? "Resets in \(days)d \(h)h" : "Resets in \(days)d"
        } else if hours >= 1 {
            let m = minutes % 60
            return "Resets in \(hours)h \(m)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }

    /// 메뉴바용 짧은 형식: "1h 20m" 또는 "24m"
    static func shortTimeUntil(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return "soon" }
        
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        
        if hours >= 1 {
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        } else {
            return "\(max(1, minutes))m"
        }
    }

    /// 절대 시각도 보고 싶을 때: "19:30"
    static func clockTime(_ date: Date?) -> String? {
        guard let date else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M/d HH:mm"
        return f.string(from: date)
    }
}
