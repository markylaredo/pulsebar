import Foundation

struct MetricHistory: Sendable {
    let capacity: Int
    private(set) var samples: [Double] = []

    init(capacity: Int = 90) {
        self.capacity = max(1, capacity)
    }

    mutating func append(_ value: Double) {
        samples.append(value.isFinite ? max(0, value) : 0)
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }
}
