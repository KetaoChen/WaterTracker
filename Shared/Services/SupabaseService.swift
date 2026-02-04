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
    
    // MARK: - API Methods
    
    /// Log water intake to Supabase
    func logWater(amount: Int, deviceId: String? = nil) async throws {
        let url = baseURL.appendingPathComponent("water_entries")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        
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
        
        let body: [String: Any] = [
            "amount": amount,
            "device_id": actualDeviceId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
        
        print("✅ Water logged to Supabase: \(amount)ml")
    }
    
    /// Fetch today's water entries from Supabase
    func fetchTodayEntries() async throws -> [CloudWaterEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let isoFormatter = ISO8601DateFormatter()
        let startOfDayString = isoFormatter.string(from: startOfDay)
        
        var components = URLComponents(url: baseURL.appendingPathComponent("water_entries"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "created_at", value: "gte.\(startOfDayString)"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case amount
        case deviceId = "device_id"
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
