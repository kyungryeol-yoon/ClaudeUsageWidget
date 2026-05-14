import SwiftUI
import AppKit

struct MenuBarLabel: View {
    let usage: Usage?
    let now: Date
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 4) {
            iconView

            if let usage {
                styleContent(usage: usage)
            } else {
                Text("—")
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if settings.menuBarIcon.isCustomImage {
            if let nsImage = resizedLogo() {
                Image(nsImage: nsImage)
            } else {
                Image(systemName: "sparkle")
            }
        } else if let symbolName = settings.menuBarIcon.symbolName {
            Image(systemName: symbolName)
        }
    }

    private func resizedLogo() -> NSImage? {
        guard let original = NSImage(named: "ClaudeLogo") else { return nil }
        let targetSize = NSSize(width: 16, height: 16)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        original.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: original.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        resized.unlockFocus()
        resized.isTemplate = false
        return resized
    }

    @ViewBuilder
    private func styleContent(usage: Usage) -> some View {
        let showGraphic = settings.menuBarIcon == .none

        switch settings.displayStyle {
        case .ring:
            HStack(spacing: 4) {
                if showGraphic {
                    Image(nsImage: makeRingImage(value: usage.fiveHour))
                }
                Text(formattedUsageText(usage))
                    .monospacedDigit()
            }
        case .dual:
            Text("5h \(Int(usage.fiveHour * 100))% · 7d \(Int(usage.weekly * 100))%")
                .monospacedDigit()
        case .bar:
            HStack(spacing: 3) {
                if showGraphic {
                    Image(nsImage: makeBarImage(value: usage.fiveHour))
                }
                Text(formattedUsageText(usage))
                    .monospacedDigit()
            }
        case .dot:
            HStack(spacing: 4) {
                if showGraphic {
                    Image(nsImage: makeDotImage(value: usage.fiveHour))
                }
                Text(formattedUsageText(usage))
                    .monospacedDigit()
            }
        case .countdown:
            Text(countdownText(usage: usage, now: now))
                .monospacedDigit()
        }
    }

    /// `.countdown` 스타일용. 가까운 쪽(5시간 vs 주간) 리셋까지 남은 시간을 메뉴바에 노출.
    private func countdownText(usage: Usage, now: Date) -> String {
        let candidates: [(label: String, date: Date)] = [
            usage.fiveHourResetsAt.map { ("5h", $0) },
            usage.weeklyResetsAt.map   { ("7d", $0) },
        ].compactMap { $0 }

        guard let next = candidates.min(by: { $0.date < $1.date }) else { return "—" }
        let remaining = ResetTimeFormatter.compact(next.date, now: now)
        return "\(next.label) \(remaining)"
    }

    private func formattedUsageText(_ usage: Usage) -> String {
        let pct = Int(usage.fiveHour * 100)
        let time = ResetTimeFormatter.compact(usage.fiveHourResetsAt, now: now)
        
        // 100%인 경우 타이머만 표시
        if usage.fiveHour >= 1.0 {
            return time.isEmpty ? "100%" : time
        }
        
        // 설정에 따라 타이머 병기
        if settings.showTimer && !time.isEmpty {
            return "\(pct)% · \(time)"
        }
        
        return "\(pct)%"
    }

    // MARK: - NSImage generators

    private func nsColor(for value: Double) -> NSColor {
        switch value {
        case ..<0.6:  return .systemGreen
        case ..<0.85: return .systemOrange
        default:      return .systemRed
        }
    }

    private func makeRingImage(value: Double, size: CGFloat = 12) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2 - 1.5

            NSColor.secondaryLabelColor.withAlphaComponent(0.3).setStroke()
            let bg = NSBezierPath()
            bg.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
            bg.lineWidth = 2
            bg.stroke()

            if value > 0 {
                self.nsColor(for: value).setStroke()
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius,
                              startAngle: 90, endAngle: 90 - CGFloat(360 * value), clockwise: true)
                arc.lineWidth = 2
                arc.lineCapStyle = .round
                arc.stroke()
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    private func makeBarImage(value: Double, width: CGFloat = 24, height: CGFloat = 7) -> NSImage {
        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            NSColor.secondaryLabelColor.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()

            let fillWidth = rect.width * CGFloat(value)
            let fillRect = NSRect(x: 0, y: 0, width: fillWidth, height: rect.height)
            self.nsColor(for: value).setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: 2, yRadius: 2).fill()
            return true
        }
        img.isTemplate = false
        return img
    }

    private func makeDotImage(value: Double, size: CGFloat = 7) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            self.nsColor(for: value).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        img.isTemplate = false
        return img
    }
}
