import SwiftUI

enum SeldonSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum SeldonControls {
    static var minimumTarget: CGFloat {
        #if os(visionOS)
        60
        #else
        44
        #endif
    }
}

enum SeldonColors {
    static let canvas: Color = {
        #if os(visionOS)
        .clear
        #else
        Color(lightRGB: (0.953, 0.965, 0.980), darkRGB: (0.039, 0.067, 0.106))
        #endif
    }()
    static let surface: Color = {
        #if os(visionOS)
        Color.primary.opacity(0.08)
        #else
        Color(lightRGB: (1, 1, 1), darkRGB: (0.075, 0.122, 0.180))
        #endif
    }()
    static let surfaceRaised: Color = {
        #if os(visionOS)
        Color.primary.opacity(0.12)
        #else
        Color(lightRGB: (0.914, 0.937, 0.965), darkRGB: (0.106, 0.165, 0.227))
        #endif
    }()
    static let accent = Color(lightRGB: (0.000, 0.424, 0.502), darkRGB: (0.439, 0.871, 0.937))
    static let accentSecondary = Color(lightRGB: (0.396, 0.318, 0.682), darkRGB: (0.671, 0.647, 0.980))
    static let separator = Color(lightRGB: (0.780, 0.827, 0.875), darkRGB: (0.204, 0.275, 0.357))
    static let attention = Color(lightRGB: (0.510, 0.325, 0.000), darkRGB: (0.945, 0.769, 0.478))
}

private extension Color {
    init(lightRGB: (CGFloat, CGFloat, CGFloat), darkRGB: (CGFloat, CGFloat, CGFloat)) {
        #if os(visionOS)
        self = Color(red: darkRGB.0, green: darkRGB.1, blue: darkRGB.2)
        #else
        self = Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? darkRGB : lightRGB
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
        #endif
    }
}

enum UsageFormatters {
    static func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1))) + "%"
    }

    static func resetText(for date: Date, now: Date = .now) -> String {
        "Resets \(localDateTime(for: date, relativeTo: now))"
    }

    static func agendaResetText(for date: Date, now: Date = .now) -> String {
        if date < now {
            return "Reported \(localDateTime(for: date, relativeTo: now))"
        }
        return resetText(for: date, now: now)
    }

    static func localDateTime(for date: Date, relativeTo now: Date = .now) -> String {
        let calendar = Calendar.current
        let template = calendar.isDate(date, inSameDayAs: now) ? "j:mm" : "MMM d, j:mm"
        return localized(template: template, date: date)
    }

    static func fullLocalDateTime(_ date: Date) -> String {
        localized(template: "yMMMMd j:mm:ss z", date: date)
    }

    static func observedText(for date: Date, now: Date = .now) -> String {
        "Observed \(localDateTime(for: date, relativeTo: now))"
    }

    static func snapshotText(for date: Date) -> String {
        "Snapshot \(localized(template: "yMMMMd j:mm", date: date))"
    }

    static func sampleAge(_ seconds: Double) -> String {
        let wholeSeconds = max(0, Int(seconds.rounded()))
        if wholeSeconds < 60 { return "Sample age \(wholeSeconds) sec" }
        let minutes = wholeSeconds / 60
        if minutes < 60 { return "Sample age \(minutes) min" }
        let hours = minutes / 60
        return "Sample age \(hours) hr"
    }

    static func duration(_ seconds: Double) -> String {
        let wholeSeconds = max(0, Int(seconds.rounded()))
        if wholeSeconds % 3_600 == 0 { return "\(wholeSeconds / 3_600) hours" }
        if wholeSeconds % 60 == 0 { return "\(wholeSeconds / 60) minutes" }
        return "\(wholeSeconds) seconds"
    }

    static func shouldShowDuration(for windowName: String) -> Bool {
        let name = windowName.localizedLowercase
        return !["minute", "hour", "day", "week", "month", "year"].contains { name.contains($0) }
    }

    private static func localized(template: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}

enum DashboardComposition {
    case compact
    case spaciousCards
    case comparison

    static func forWidth(_ width: CGFloat, accessibilitySize: Bool) -> DashboardComposition {
        if accessibilitySize || width < 680 { return .compact }
        if width < 1_040 { return .spaciousCards }
        return .comparison
    }
}

extension View {
    @ViewBuilder
    func seldonGroupBackground(cornerRadius: CGFloat = 20) -> some View {
        #if os(visionOS)
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        #else
        background(SeldonColors.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        #endif
    }
}
