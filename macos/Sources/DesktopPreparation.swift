import ApplicationServices
import Foundation

// Cross-process Accessibility messages may wait for the target app. They must
// never occupy AppKit's animation/event thread, even during a cold Codex start.
final class DesktopPreparation {
    private let queue = DispatchQueue(label: "CodexWelcome.desktop", qos: .userInitiated)

    func request(pid: pid_t, frame: CGRect, maximize: Bool, simulatedDelay: Double = 0,
                 completion: @escaping (Bool) -> Void) {
        queue.async {
            let ready: Bool
            if simulatedDelay > 0 { Thread.sleep(forTimeInterval: simulatedDelay); ready = true }
            else { ready = !maximize || Self.prepare(pid: pid, frame: frame) }
            DispatchQueue.main.async { completion(ready) }
        }
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    private static func prepare(pid: pid_t, frame: CGRect) -> Bool {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.12)
        var chosen: AXUIElement?
        if let main = attribute(application, kAXMainWindowAttribute) { chosen = (main as! AXUIElement) }
        else { chosen = (attribute(application, kAXWindowsAttribute) as? [AXUIElement])?.first }
        guard let window = chosen else { return false }
        AXUIElementSetMessagingTimeout(window, 0.12)
        if attribute(window, "AXFullScreen") as? Bool == true {
            _ = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse)
            return false
        }
        if attribute(window, kAXMinimizedAttribute) as? Bool == true {
            _ = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            return false
        }
        guard let currentPosition = attribute(window, kAXPositionAttribute),
              let currentSize = attribute(window, kAXSizeAttribute) else { return false }
        var position = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(currentPosition as! AXValue, .cgPoint, &position),
              AXValueGetValue(currentSize as! AXValue, .cgSize, &size) else { return false }
        let move = abs(position.x - frame.minX) >= 4 || abs(position.y - frame.minY) >= 4
        let resize = abs(size.width - frame.width) >= 4 || abs(size.height - frame.height) >= 4
        if !move && !resize { return true }
        position = frame.origin; size = frame.size
        if move, let value = AXValueCreate(.cgPoint, &position) {
            _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if resize, let value = AXValueCreate(.cgSize, &size) {
            _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
        // Verify on the next request rather than blocking for another repaint.
        return false
    }
}
