import Foundation

class GlobalFunctions {
    static func makePayload(with prompt: String, model: String) -> String? {
        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true
        ]
        // JSONSerialization handles all escaping (quotes, newlines, etc.) correctly
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonStr
    }

    static func parsePlainText(_ jsonStr: String) -> String {
        let lines = jsonStr.components(separatedBy: .newlines)
        var result = ""
        for line in lines {
            guard let data = line.data(using: .utf8) else { continue }
            if let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
               let aiResponse = json["response"] as? String {
                result += aiResponse
            }
        }
        return result
    }
    
    static func isOllamaAvailable() -> Bool {
        let listCommand = "/usr/local/bin/ollama list"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", listCommand]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            return !output.lowercased().contains("command not found")
        } catch {
            print("Error checking Ollama: \(error)")
            return false
        }
    }
    
    static func displayName(for internalName: String) -> String {
        let components = internalName.split(separator: ":").map(String.init)
        let baseName = components.first ?? internalName
        let variant = components.last ?? ""
        
        // Look up the friendly name in modelsUser; fallback to the baseName if not found
        let friendlyBase = GlobalVariables.modelsUser[baseName] ?? baseName
        
        // Returns "Google Gemma3 (1b)" instead of "gemma3:1b"
        return variant.isEmpty ? friendlyBase : "\(friendlyBase) (\(variant))"
    }
}
