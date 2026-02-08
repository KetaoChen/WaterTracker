import Foundation
#if os(iOS)
import UIKit
#endif

/// Supabase API service for syncing water entries to cloud
actor SupabaseService {
    static let shared = SupabaseService()
    
    private let projectURL = "https://yzacvyfuhmguelbpzrxn.supabase.co"
    private let apiKey = "sb_publishable_iR35kgSqCf1bAb18oSjBOQ_FvMbIwS_"
    
    private var baseURL: URL {
        URL(string: "\(projectURL)/rest/v1")!
    }
    
    /// Get authorization header with user token if available
    private func getAuthHeaders() async -> [String: String] {
        var headers = [
            "apikey": apiKey,
            "Content-Type": "application/json"
        ]
        
        if let token = await MainActor.run(body: { AuthManager.shared.getAccessToken() }) {
            headers["Authorization"] = "Bearer \(token)"
        } else {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        
        return headers
    }
    
    // MARK: - API Methods
    
    /// Log water intake to Supabase
    /// Returns the created record ID
    @discardableResult
    func logWater(amount: Int, deviceId: String? = nil) async throws -> String {
        let url = baseURL.appendingPathComponent("water_entries")
        let headers = await getAuthHeaders()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        var actualDeviceId = deviceId ?? "unknown"
        #if os(iOS)
        if deviceId == nil {
            actualDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-unknown"
        }
        #elseif os(watchOS)
        if deviceId == nil {
            actualDeviceId = "watch-\(UUID().uuidString.prefix(8))"
        }
        #endif
        
        var body: [String: Any] = [
            "amount": amount,
            "device_id": actualDeviceId
        ]
        
        // Add user_id if authenticated
        if let userId = await MainActor.run(body: { AuthManager.shared.getUserId() }) {
            body["user_id"] = userId
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
        
        // Parse response to get the created record ID
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([CloudWaterEntry].self, from: data)
        guard let createdEntry = entries.first else {
            throw SupabaseError.invalidResponse
        }
        
        print("✅ Water logged to Supabase: \(amount)ml (id: \(createdEntry.id))")
        return createdEntry.id
    }
    
    /// Delete a water entry from Supabase
    func deleteEntry(id: String) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("water_entries"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id)")
        ]
        
        let headers = await getAuthHeaders()
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
        
        print("✅ Water entry deleted from Supabase: \(id)")
    }
    
    /// Fetch today's water entries from Supabase
    func fetchTodayEntries() async throws -> [CloudWaterEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let isoFormatter = ISO8601DateFormatter()
        let startOfDayString = isoFormatter.string(from: startOfDay)
        
        var components = URLComponents(url: baseURL.appendingPathComponent("water_entries"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "created_at", value: "gte.\(startOfDayString)"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        
        // Filter by user_id if authenticated
        if let userId = await MainActor.run(body: { AuthManager.shared.getUserId() }) {
            queryItems.append(URLQueryItem(name: "user_id", value: "eq.\(userId)"))
        }
        components.queryItems = queryItems
        
        let headers = await getAuthHeaders()
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CloudWaterEntry].self, from: data)
    }
    
    /// Get today's total from Supabase
    func fetchTodayTotal() async throws -> Int {
        let entries = try await fetchTodayEntries()
        return entries.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Models

struct CloudWaterEntry: Codable {
    let id: String
    let createdAt: Date
    let amount: Int
    let deviceId: String?
    let userId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case amount
        case deviceId = "device_id"
        case userId = "user_id"
    }
}

// MARK: - Errors

enum SupabaseError: Error, LocalizedError {
    case requestFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .requestFailed: return "Failed to connect to Supabase"
        case .invalidResponse: return "Invalid response from server"
        }
    }
}
