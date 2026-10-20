import Foundation

enum JellyGeometry {
    static func radii(progress: Double, width: Double, height: Double) -> (Double, Double) {
        let p = min(1, max(0, progress))
        let eased = p * p * p * (p * (p * 6 - 15) + 10)
        let jelly = 0.16 * sin(3 * .pi * p) * sin(.pi * p) * (1 - p)
        let radius = max(0.01, hypot(width, height) * 0.56 * eased)
        return (radius * (1 + jelly), radius / (1 + jelly))
    }
}
