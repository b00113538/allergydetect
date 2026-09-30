import Foundation

extension Double {
    /// 0.834 → "83%"
    var percentString: String { formatted(.percent.precision(.fractionLength(0))) }
}

extension Date {
    var relativeString: String { formatted(.relative(presentation: .named)) }
    var timeString: String { formatted(date: .omitted, time: .shortened) }
}
