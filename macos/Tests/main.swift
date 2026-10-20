import Foundation

for (width, height) in [(1280.0,720.0),(1920,1080),(2560,1600),(3440,1440),(900,1200)] {
    var previousArea = 0.0
    for index in 0...100 {
        let (rx, ry) = JellyGeometry.radii(progress: Double(index)/100, width: width, height: height)
        precondition(rx.isFinite && ry.isFinite && rx > 0 && ry > 0)
        precondition(rx*ry >= previousArea-0.000001, "The reveal must never move backwards")
        previousArea = rx*ry
        let corner = pow(width/2/rx,2)+pow(height/2/ry,2)
        if index >= 90 { precondition(corner <= 0.95, "Corners must remain clear at the end") }
    }
}
print("Mac jelly geometry: PASS")
