import Foundation
import AppKit

class GlobalFunctions {
    static func makePayload(with prompt: String, model: String, stream: Bool = true) -> String? {
        let payload: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": stream
        ]
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

    static func fetchCommunityKnowledge() async -> String {
        guard let url = URL(string: "https://lopilot-learning-api.miles14.workers.dev/list") else { return "" }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Decodes the {"context": "...data..."} JSON from your Worker
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               let context = json["context"] {
                return context
            }
        } catch {
            print("Cloudflare Fetch Error: \(error)")
        }
        return ""
    }
    
    static func submitLearningEntry(instruction: String) async -> Bool {
        guard let url = URL(string: "https://lopilot-learning-api.miles14.workers.dev/add") else { return false }
        
        let body: [String: Any] = ["instruction": instruction]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                return true
            }
        } catch {
            print("Cloudflare Submit Error: \(error)")
        }
        return false
    }
    
    static func detectCorrection(userPrompt: String, model: String, onLearnedSomething: ((_ learnedString: String) -> Void)? = nil) async -> String {
        let judgePrompt = """
        [SYSTEM: ACT AS A LOGIC GATE]
        Identify if the user message is a permanent RULE, a technical CORRECTION, or just a TASK/CHAT.

        [CATEGORIES]
        1. RULE (Behavioral): "Be more polite", "Stop using emojis".
        2. CORRECTION (Technical): "That code has a syntax error", "Actually, that function is deprecated".
        3. TASK/CHAT (Ignore): "Write a poem", "What time is it?", "Thanks!".

        [EXAMPLES]
        - User: "No, that method returns a SyntaxError" -> RULE: "Avoid using [Method Name] as it causes a SyntaxError; use the standard approach instead."
        - User: "Actually, in Swift 6 you need to use @MainActor" -> RULE: "When writing Swift 6 code, always apply @MainActor to UI-related classes."
        - User: "Explain why my code is broken" -> TASK: "NOCORRECTION"

        [INSTRUCTIONS]
        - If Category 1 or 2: Output ONLY the concise instruction for the AI to follow in the future.
        - If Category 3: Output ONLY 'NOCORRECTION'.
        - NO INTROS. NO BOLDING. NO QUOTES.

        USER MESSAGE: "\(userPrompt)"
        """
        
        guard let payload = makePayload(with: judgePrompt, model: model, stream: false) else { return "NOCORRECTION" }
        guard let url = URL(string: "http://localhost:11434/api/generate") else { return "NOCORRECTION" }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                
                // Post-processing to strip common AI "helpful" debris
                let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "RULE:", with: "")
                    .replacingOccurrences(of: "TASK:", with: "")
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                onLearnedSomething?(cleaned)
                
                return cleaned
            }
        } catch {
            print("Judge Error: \(error)")
        }
        return "NOCORRECTION"
    }
}
