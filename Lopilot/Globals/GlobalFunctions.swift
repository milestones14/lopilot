import Foundation
import AppKit

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
    
    static func getModelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    static func getMarketingName() -> String {
        let identifier = getModelIdentifier()
        let path = "/System/Library/PrivateFrameworks/ServerInformation.framework/Versions/A/Resources/en.lproj/SIMachineAttributes.plist"
        
        if let dict = NSDictionary(contentsOfFile: path),
           let modelDict = dict[identifier] as? [String: Any],
           let localizedDict = modelDict["_LOCALIZABLE_"] as? [String: String],
           let name = localizedDict["marketingModel"] {
            return name
        }
        return identifier // Fallback to "Mac16,10" if name not found
    }
    
    static func getSystemContext() -> (lastApp: String, allApps: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // 1. Filter for regular user-facing apps, excluding your own
        let userApps = runningApps.filter {
            $0.activationPolicy == .regular &&
            $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        
        // 2. Identify the "Last Active" App
        // We check the actual frontmost app first.
        let frontmost = NSWorkspace.shared.frontmostApplication
        
        let lastActiveAppName: String
        if let front = frontmost, front.bundleIdentifier != Bundle.main.bundleIdentifier {
            // If the user is currently focused on another app, that's the one!
            lastActiveAppName = front.localizedName ?? "Unknown"
        } else {
            // If the user is focused on YOUR app (Lopilot), we grab the first
            // available user app as the best guess for what was open behind it.
            lastActiveAppName = userApps.first?.localizedName ?? "Unknown"
        }
        
        // 3. Create a clean comma-separated list of all open apps
        let allAppsString = userApps
            .compactMap { $0.localizedName }
            .joined(separator: ", ")
        
        return (lastActiveAppName, allAppsString)
    }
}
