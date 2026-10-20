import Foundation

enum WelcomePreferences {
    static func validatedName(_ value: String) throws -> String {
        let name = value.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        let containsControl = name.unicodeScalars.contains { scalar in
            let code = scalar.value
            return code <= 0x1F || (0x7F...0x9F).contains(code) || (0x202A...0x202E).contains(code) || (0x2066...0x2069).contains(code)
        }
        guard (1...20).contains(name.unicodeScalars.count), !containsControl else {
            throw NSError(domain: "CodexWelcome", code: 2, userInfo: [NSLocalizedDescriptionKey: "请输入 1–20 个字符，不含换行或控制字符。"])
        }
        return name
    }
    static func read(at url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url), let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return values
    }
    static func name(at url: URL) -> String {
        (try? validatedName(read(at: url)["WelcomeName"] as? String ?? "JimmSun")) ?? "JimmSun"
    }
    static func set(_ value: String, forKey key: String, at url: URL) throws {
        var values = read(at: url)
        if key == "WelcomeName" { values[key] = try validatedName(value) } else { values[key] = value }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
    }
}
