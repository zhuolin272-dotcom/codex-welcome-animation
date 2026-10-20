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

let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CodexWelcome-test-" + UUID().uuidString)
let config = directory.appendingPathComponent("config.json")
try WelcomePreferences.set("/Applications/Codex.app", forKey: "CodexPath", at: config)
for name in ["Alex Sun", "小明", "Élodie 2026", "WWWWWWWWWWWWWWWWWWWW"] {
    try WelcomePreferences.set(name, forKey: "WelcomeName", at: config)
    precondition(WelcomePreferences.name(at: config) == name)
    precondition(WelcomePreferences.read(at: config)["CodexPath"] as? String == "/Applications/Codex.app")
}
let normalized = try WelcomePreferences.validatedName(" e\u{301} ")
precondition(normalized == "é")
for invalid in ["", "  ", String(repeating: "x", count: 21), "A\nB", "A\u{202E}B"] {
    do { _ = try WelcomePreferences.validatedName(invalid); fatalError("Invalid name was accepted") } catch {}
}
try FileManager.default.removeItem(at: config)
try FileManager.default.removeItem(at: directory)
print("Mac preferences: Unicode, normalization, validation, preserved CodexPath PASS")
