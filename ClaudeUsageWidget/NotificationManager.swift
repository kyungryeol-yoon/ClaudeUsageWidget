import Foundation
import UserNotifications

/// 사용량 임계치 알림 + 리셋 임박 알림을 담당.
///
/// 임계치는 fiveHour / weekly 각 버킷마다 0.6, 0.85, 0.95 세 단계.
/// 같은 윈도우 내에서 한 번 발화하면 다시 쏘지 않으며,
/// `resetsAt`이 바뀌면(=새 윈도우) 발화 기록을 초기화한다.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private static let thresholds: [Double] = [0.6, 0.85, 0.95]

    // UserDefaults 키
    private static let kFiredFiveHour     = "notif_fired_fiveHour"     // [Double]
    private static let kFiredWeekly       = "notif_fired_weekly"       // [Double]
    private static let kFiveHourWindowKey = "notif_window_fiveHour"    // String (resetsAt iso)
    private static let kWeeklyWindowKey   = "notif_window_weekly"      // String
    private static let kScheduledFiveHour = "notif_scheduledReset_fiveHour" // String (resetsAt iso for which reminder was scheduled)
    private static let kScheduledWeekly   = "notif_scheduledReset_weekly"

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            guard settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    // MARK: - Public API

    func handle(usage: Usage) {
        let settings = AppSettings.shared
        guard settings.notificationsEnabled else { return }
        requestAuthorizationIfNeeded()

        if settings.thresholdAlertsEnabled {
            checkBucket(value: usage.fiveHour,
                        resetsAt: usage.fiveHourResetsAt,
                        bucketLabel: "5시간",
                        firedKey: Self.kFiredFiveHour,
                        windowKey: Self.kFiveHourWindowKey)

            checkBucket(value: usage.weekly,
                        resetsAt: usage.weeklyResetsAt,
                        bucketLabel: "주간",
                        firedKey: Self.kFiredWeekly,
                        windowKey: Self.kWeeklyWindowKey)
        }

        if settings.resetReminderEnabled {
            scheduleResetReminder(resetsAt: usage.fiveHourResetsAt,
                                  bucketLabel: "5시간",
                                  identifierKey: Self.kScheduledFiveHour,
                                  leadMinutes: settings.resetReminderMinutes)
            scheduleResetReminder(resetsAt: usage.weeklyResetsAt,
                                  bucketLabel: "주간",
                                  identifierKey: Self.kScheduledWeekly,
                                  leadMinutes: settings.resetReminderMinutes)
        }
    }

    // MARK: - Threshold

    private func checkBucket(value: Double,
                             resetsAt: Date?,
                             bucketLabel: String,
                             firedKey: String,
                             windowKey: String) {
        let ud = UserDefaults.standard

        // 새 윈도우 감지 → 발화 기록 리셋
        let windowId = resetsAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
        let storedWindow = ud.string(forKey: windowKey) ?? ""
        if windowId != storedWindow {
            ud.set(windowId, forKey: windowKey)
            ud.removeObject(forKey: firedKey)
        }

        var fired = Set(ud.array(forKey: firedKey) as? [Double] ?? [])

        for threshold in Self.thresholds where value >= threshold && !fired.contains(threshold) {
            fire(threshold: threshold, value: value, bucketLabel: bucketLabel)
            fired.insert(threshold)
        }

        ud.set(Array(fired), forKey: firedKey)
    }

    private func fire(threshold: Double, value: Double, bucketLabel: String) {
        let pct = Int(threshold * 100)
        let actualPct = Int(value * 100)

        let content = UNMutableNotificationContent()
        content.title = "Claude \(bucketLabel) 사용량 \(pct)% 도달"
        content.body = "현재 \(actualPct)% 사용 중입니다."
        content.sound = threshold >= 0.95 ? .defaultCritical : .default

        let request = UNNotificationRequest(
            identifier: "claude.threshold.\(bucketLabel).\(pct).\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
    }

    // MARK: - Reset reminder

    private func scheduleResetReminder(resetsAt: Date?,
                                       bucketLabel: String,
                                       identifierKey: String,
                                       leadMinutes: Int) {
        guard let resetsAt else { return }
        let fireDate = resetsAt.addingTimeInterval(-Double(leadMinutes) * 60)
        guard fireDate > Date() else { return }

        let ud = UserDefaults.standard
        let resetIso = ISO8601DateFormatter().string(from: resetsAt)
        let scheduledFor = ud.string(forKey: identifierKey) ?? ""
        // 같은 리셋 시각에 대해서는 한 번만 스케줄
        if scheduledFor == resetIso { return }

        // 이전에 잡아둔 같은 버킷 알림 제거
        let identifier = "claude.resetSoon.\(bucketLabel)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Claude \(bucketLabel) 한도 리셋 임박"
        content.body = "\(leadMinutes)분 뒤 \(bucketLabel) 사용량이 초기화됩니다."
        content.sound = .default

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if error == nil {
                UserDefaults.standard.set(resetIso, forKey: identifierKey)
            }
        }
    }
}
