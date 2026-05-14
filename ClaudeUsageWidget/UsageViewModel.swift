import Foundation
import Combine

struct Usage {
    let fiveHour: Double
    let weekly: Double
    let fiveHourResetsAt: Date?
    let weeklyResetsAt: Date?
}

@MainActor
class UsageViewModel: ObservableObject {
    @Published var usage: Usage?
    @Published var lastError: String?
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var isStale = false  // 마지막 갱신이 실패해서 캐시된 값을 보여주는 중
    @Published var clockTick: Date = Date()  // 메뉴바 카운트다운 갱신용 (30초 주기)

    private let settings = AppSettings.shared
    private var timer: Timer?
    private var clockTimer: Timer?
    private var settingsCancellable: AnyCancellable?
    
    // 캐시 키
    private static let cacheKeyFiveHour = "cache_fiveHour"
    private static let cacheKeyWeekly = "cache_weekly"
    private static let cacheKeyFiveHourReset = "cache_fiveHourReset"
    private static let cacheKeyWeeklyReset = "cache_weeklyReset"
    private static let cacheKeyLastUpdated = "cache_lastUpdated"
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    init() {
        // 앱 시작 시 캐시된 값 먼저 로드
        loadCachedUsage()
        
        Task { await refresh() }
        restartTimer()
        startClock()

        settingsCancellable = settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.restartTimer()
                }
            }
    }

    deinit {
        timer?.invalidate()
        clockTimer?.invalidate()
    }

    private func startClock() {
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.clockTick = Date()
            }
        }
    }
    
    func refresh() async {
        isLoading = true
        
        do {
            let credentials = try CredentialsLoader.load()
            let response = try await UsageFetcher.fetch(accessToken: credentials.accessToken)
            
            let newUsage = Usage(
                fiveHour: response.fiveHour.utilization / 100.0,
                weekly:   response.sevenDay.utilization / 100.0,
                fiveHourResetsAt: Self.parseDate(response.fiveHour.resetsAt),
                weeklyResetsAt:   Self.parseDate(response.sevenDay.resetsAt)
            )
            
            self.usage = newUsage
            self.lastUpdated = Date()
            self.lastError = nil
            self.isStale = false

            // 성공 시 캐시에 저장
            saveUsageToCache(newUsage)

            // 알림 처리 (임계치 + 리셋 임박)
            NotificationManager.shared.handle(usage: newUsage)
            
        } catch {
            print("Refresh error: \(error)")
            
            // 이전 값이 있으면 유지하고 stale 표시
            if usage != nil {
                self.isStale = true
                self.lastError = error.localizedDescription
            } else {
                // 이전 값도 없으면 에러만 표시
                self.lastError = error.localizedDescription
            }
        }
        
        isLoading = false
    }
    
    // MARK: - 캐시 (UserDefaults)
    
    private func saveUsageToCache(_ usage: Usage) {
        let ud = UserDefaults.standard
        ud.set(usage.fiveHour, forKey: Self.cacheKeyFiveHour)
        ud.set(usage.weekly, forKey: Self.cacheKeyWeekly)
        ud.set(Date(), forKey: Self.cacheKeyLastUpdated)
        
        if let r = usage.fiveHourResetsAt {
            ud.set(r, forKey: Self.cacheKeyFiveHourReset)
        }
        if let r = usage.weeklyResetsAt {
            ud.set(r, forKey: Self.cacheKeyWeeklyReset)
        }
    }
    
    private func loadCachedUsage() {
        let ud = UserDefaults.standard
        let fiveHour = ud.double(forKey: Self.cacheKeyFiveHour)
        let weekly = ud.double(forKey: Self.cacheKeyWeekly)
        
        // 캐시가 존재하는지 확인 (0은 기본값이라 lastUpdated로 판별)
        guard let cachedDate = ud.object(forKey: Self.cacheKeyLastUpdated) as? Date else {
            return
        }
        
        self.usage = Usage(
            fiveHour: fiveHour,
            weekly: weekly,
            fiveHourResetsAt: ud.object(forKey: Self.cacheKeyFiveHourReset) as? Date,
            weeklyResetsAt: ud.object(forKey: Self.cacheKeyWeeklyReset) as? Date
        )
        self.lastUpdated = cachedDate
        self.isStale = true  // 캐시된 값이므로 stale 표시
    }
    
    private func restartTimer() {
        timer?.invalidate()
        let interval = settings.refreshInterval.seconds
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.refresh()
            }
        }
    }
    
    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return isoFormatter.date(from: raw) ?? isoFormatterNoFraction.date(from: raw)
    }
}
