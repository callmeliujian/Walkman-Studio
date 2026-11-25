enum ABRepeatState: Equatable {
    case off
    case startMarked(Double)
    case looping(Range<Double>)

    var range: Range<Double>? {
        if case .looping(let range) = self { return range }
        return nil
    }

    var start: Double? {
        if case .startMarked(let time) = self { return time }
        return range?.lowerBound
    }

    func canAdvance(at time: Double, duration: Double) -> Bool {
        guard time.isFinite, time >= 0 else { return false }
        switch self {
        case .off:
            return duration <= 0 || time < duration
        case .startMarked(let start):
            // Require at least one playhead update between the two markers.
            return time >= start + 0.1 && (duration <= 0 || time <= duration)
        case .looping:
            return true
        }
    }
}
