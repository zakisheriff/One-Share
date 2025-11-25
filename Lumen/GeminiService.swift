import Foundation
import Combine
import SwiftUI

// NOTE: The 'FileMetadata' struct must be defined in another file (e.g., 'Models.swift')
// for this code to compile.

// MARK: - Error Types
enum GeminiSearchError: LocalizedError {
    case apiKeyMissing
    case apiRequestFailed(statusCode: Int, message: String)
    case invalidResponse
    case jsonParsingFailed
    case fileNotFound(path: String)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing: return "API Key is missing."
        case .apiRequestFailed(let code, let msg): return "API Request Failed (\(code)): \(msg)"
        case .invalidResponse: return "Invalid response from AI model."
        case .jsonParsingFailed: return "Failed to parse AI response."
        case .fileNotFound(let path): return "File not found: \(path)"
        }
    }
}

class GeminiService: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "GeminiAPIKey")
        }
    }
    
    // WARNING: This is a critical security risk. Never hardcode API keys in production apps.
    private let defaultKey = "AIzaSyC-wAzFOjaUobFGZJfn_Gt_wViZ-BMU1mw"
    
    // UPDATED MODELS: Switched to Gemini 2.5 models to fix persistent 404 errors.
    private let primaryModel = "gemini-2.5-flash"
    private let fallbackModel = "gemini-2.5-pro" 

    // Debug properties
    @Published var lastRawResponse: String = ""
    @Published var lastPrompt: String = ""

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "GeminiAPIKey") ?? defaultKey
    }
    
    // MARK: - Core Search Logic
    func search(query: String, files: [FileMetadata]) async throws -> [FileMetadata] {
        guard !apiKey.isEmpty else {
            throw GeminiSearchError.apiKeyMissing
        }
        
        print("Starting search for '\(query)' across \(files.count) files...")
        
        if files.isEmpty {
            print("Error: No files to search.")
            throw GeminiSearchError.fileNotFound(path: "No files indexed. Please wait for scanning to complete.")
        }
        
        // Use the initial file list and filter to a manageable size (e.g., 2000)
        // Gemini 1.5 Flash has a large context window, so we can afford more files.
        let recentFiles = files.sorted(by: { $0.modificationDate > $1.modificationDate }).prefix(2000)
        
        do {
            return try await performSearch(query: query, files: Array(recentFiles), model: primaryModel)
        } catch let error as GeminiSearchError {
            // Check for 404 (Not Found) or 429 (Rate Limit) errors
            if case let .apiRequestFailed(statusCode, _) = error, statusCode == 404 || statusCode == 429 {
                print("Primary model (\(primaryModel)) failed (Status \(statusCode)). Retrying with fallback (\(fallbackModel))...")
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                return try await performSearch(query: query, files: Array(recentFiles), model: fallbackModel)
            }
            throw error
        }
    }
    
    // MARK: - Refactored Search Execution
    private func performSearch(query: String, files: [FileMetadata], model: String) async throws -> [FileMetadata] {
        
        // 1. Prepare file list for prompt
        let isoFormatter = ISO8601DateFormatter()
        let filesJSON = files.map { file in
            return [
                "id": file.path,
                "name": file.name,
                "type": (file.name as NSString).pathExtension,
                "date": isoFormatter.string(from: file.modificationDate),
                "size": file.size
            ]
        }
        
        let filesListString = try String(data: JSONSerialization.data(withJSONObject: filesJSON), encoding: .utf8) ?? "[]"

        // 2. Construct the prompt
        let currentDate = Date().formatted(date: .long, time: .shortened)
        let prompt = """
        You are a smart file search assistant.
        Current Date: \(currentDate)
        User Query: "\(query)"
        
        Here is a list of file metadata in JSON format:
        \(filesListString)
        
        Task: Identify the **top 5 files** that best match the user's query based on filename, date, type, and size.
        - For relative dates like "last week", use the Current Date as a reference.
        - For specific dates like "July 2025", match the file modification date.
        
        Return ONLY a JSON array of the file IDs (paths) of the matching files.
        Example format: ["/path/to/file1", "mtp://path/to/file2"]
        """

        // Debug: Capture prompt
        DispatchQueue.main.async {
            self.lastPrompt = prompt
        }

        // 3. Prepare the API Request
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "array",
                    "items": ["type": "string"]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // 4. Execute the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiSearchError.apiRequestFailed(statusCode: 0, message: "Network error: Invalid HTTP response.")
        }
        
        // 5. Handle HTTP Errors
        if httpResponse.statusCode != 200 {
            var message = "Unknown API Error"
            
            // Attempt to parse the JSON error message from the API response body
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDict = json["error"] as? [String: Any],
               let errorMsg = errorDict["message"] as? String {
                message = errorMsg
            } else {
                message = String(data: data, encoding: .utf8) ?? message
            }
            
            print("Gemini API Error (\(model), Status \(httpResponse.statusCode)): \(message)")
            throw GeminiSearchError.apiRequestFailed(statusCode: httpResponse.statusCode, message: message)
        }
        
        // 6. Parse JSON Response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            
            // Clean up any potential markdown (though responseMimeType should prevent it)
            let cleanText = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Debug: Print raw response text
            print("Raw AI Response: \(cleanText)")
            DispatchQueue.main.async {
                self.lastRawResponse = cleanText
            }
            
            if let data = cleanText.data(using: .utf8),
               let paths = try? JSONDecoder().decode([String].self, from: data) {
                
                // Exact match
                var matchedFiles = files.filter { paths.contains($0.path) }
                
                // Fuzzy match fallback: If exact path fails, try matching by filename
                if matchedFiles.isEmpty {
                    print("No exact matches. Trying fuzzy filename match...")
                    for path in paths {
                        let filename = (path as NSString).lastPathComponent
                        if let fuzzyMatch = files.first(where: { $0.name == filename || $0.path.hasSuffix(filename) }) {
                            if !matchedFiles.contains(fuzzyMatch) {
                                matchedFiles.append(fuzzyMatch)
                            }
                        }
                    }
                }
                
                print("Found \(matchedFiles.count) matching files.")
                return matchedFiles
            }
            
            print("JSON Parsing Failed. Raw text: \(text)")
            throw GeminiSearchError.jsonParsingFailed
        }
        
        // Debugging: Print raw response if structure is unexpected
        if let rawString = String(data: data, encoding: .utf8) {
            print("Invalid Response Structure. Raw: \(rawString)")
            DispatchQueue.main.async {
                self.lastRawResponse = rawString
            }
        }
        
        throw GeminiSearchError.invalidResponse
    }
}