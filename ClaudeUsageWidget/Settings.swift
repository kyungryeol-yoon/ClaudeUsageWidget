import Foundation
import Combine
import ServiceManagement

enum DisplayStyle: String, CaseIterable, Identifiable, Codable {
    case ring
    case dual
    case bar
    case dot
    case countdown

    var id: String { rawValue }
    var label: String {
        switch self {
        case .ring:      return "링 + 퍼센트"
        case .dual:      return "5시간 · 주간 듀얼"
        case .bar:       return "바 + 퍼센트"
        case .dot:       return "도트 + 퍼센트"
        case .countdown: return "리셋까지 카운트다운"
        }
    }
}

enum ResetReminderLead: Int, CaseIterable, Identifiable, Codable {
    case fiveMin = 5
    case tenMin = 10
    case fifteenMin = 15
    case thirtyMin = 30

    var id: Int { rawValue }
    var label: String { "\(rawValue)분 전" }
}

enum RefreshInterval: Int, CaseIterable, Identifiable, Codable {
    case fiveMin = 300
    case tenMin = 600
    case twentyMin = 1200
    case thirtyMin = 1800
    case oneHour = 3600
    
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .fiveMin:   return "5분"
        case .tenMin:    return "10분"
        case .twentyMin: return "20분"
        case .thirtyMin: return "30분"
        case .oneHour:   return "1시간"
        }
    }
    
    var seconds: TimeInterval { TimeInterval(rawValue) }
}

enum MenuBarIcon: String, CaseIterable, Identifiable, Codable {
    case claudeLogo
    case sparkle
    case sparkles
    case star
    case bolt
    case none
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .claudeLogo: return "Claude 로고"
        case .sparkle:    return "✦ 반짝임"
        case .sparkles:   return "✦✧ 반짝임 (다중)"
        case .star:       return "★ 별"
        case .bolt:       return "⚡ 번개"
        case .none:       return "(없음)"
        }
    }
    
    var symbolName: String? {
        switch self {
        case .claudeLogo: return nil
        case .sparkle:    return "sparkle"
        case .sparkles:   return "sparkles"
        case .star:       return "star.fill"
        case .bolt:       return "bolt.fill"
        case .none:       return nil
        }
    }
    
    var isCustomImage: Bool {
        self == .claudeLogo
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var displayStyle: DisplayStyle {
        didSet { UserDefaults.standard.set(displayStyle.rawValue, forKey: "displayStyle") }
    }
    
    @Published var refreshInterval: RefreshInterval {
        didSet { UserDefaults.standard.set(refreshInterval.rawValue, forKey: "refreshInterval") }
    }
    
    @Published var menuBarIcon: MenuBarIcon {
        didSet { UserDefaults.standard.set(menuBarIcon.rawValue, forKey: "menuBarIcon") }
    }
    
    @Published var showTimer: Bool {
        didSet { UserDefaults.standard.set(showTimer, forKey: "showTimer") }
    }

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    @Published var thresholdAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(thresholdAlertsEnabled, forKey: "thresholdAlertsEnabled") }
    }

    @Published var resetReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(resetReminderEnabled, forKey: "resetReminderEnabled") }
    }

    @Published var resetReminderMinutes: Int {
        didSet { UserDefaults.standard.set(resetReminderMinutes, forKey: "resetReminderMinutes") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
    
    private init() {
        let styleRaw = UserDefaults.standard.string(forKey: "displayStyle") ?? DisplayStyle.ring.rawValue
        self.displayStyle = DisplayStyle(rawValue: styleRaw) ?? .bar
        
        let intervalRaw = UserDefaults.standard.integer(forKey: "refreshInterval")
        self.refreshInterval = RefreshInterval(rawValue: intervalRaw) ?? .fiveMin
        
        let iconRaw = UserDefaults.standard.string(forKey: "menuBarIcon") ?? MenuBarIcon.claudeLogo.rawValue
        self.menuBarIcon = MenuBarIcon(rawValue: iconRaw) ?? .claudeLogo
        
        self.showTimer = UserDefaults.standard.bool(forKey: "showTimer")

        let ud = UserDefaults.standard
        // 첫 실행 기본값: 알림 끔, 켜면 임계치+리셋 임박 둘 다 기본 ON
        self.notificationsEnabled = ud.object(forKey: "notificationsEnabled") as? Bool ?? false
        self.thresholdAlertsEnabled = ud.object(forKey: "thresholdAlertsEnabled") as? Bool ?? true
        self.resetReminderEnabled = ud.object(forKey: "resetReminderEnabled") as? Bool ?? true
        let savedLead = ud.integer(forKey: "resetReminderMinutes")
        self.resetReminderMinutes = ResetReminderLead(rawValue: savedLead)?.rawValue ?? ResetReminderLead.tenMin.rawValue

        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
