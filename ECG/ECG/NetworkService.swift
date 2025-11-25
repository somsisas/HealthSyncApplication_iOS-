import Foundation
import UIKit
import Combine

class NetworkService: ObservableObject {
    // TODO: Replace with your actual backend URL once deployed
    private let baseURL = "http://192.168.1.28:3000/api"
    private let apiKey = "health-sync-api-key-change-me-12345"// We'll set this up in backend
    
    enum NetworkError: Error {
        case invalidURL
        case encodingError
        case serverError(String)
        case noResponse
    }
    
    // MARK: - Sync Heart Rate Data
    
    func syncHeartRateData(_ data: [HeartRateDataPoint]) async throws {
        guard let url = URL(string: "\(baseURL)/health-data/heartrate") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let payload = HeartRatePayload(data: data)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(payload)
        } catch {
            throw NetworkError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.serverError(errorMessage)
        }
    }
    
    // MARK: - Sync ECG Data
    
    func syncECGData(_ data: [ECGDataPoint]) async throws {
        guard let url = URL(string: "\(baseURL)/health-data/ecg") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let payload = ECGPayload(data: data)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(payload)
        } catch {
            throw NetworkError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.serverError(errorMessage)
        }
    }
    
    // MARK: - Test Connection
    
    func testConnection() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noResponse
        }
        
        return (200...299).contains(httpResponse.statusCode)
    }
}

// MARK: - Payload Models

struct HeartRatePayload: Codable {
    let data: [HeartRateDataPoint]
    let deviceInfo: DeviceInfo
    
    init(data: [HeartRateDataPoint]) {
        self.data = data
        self.deviceInfo = DeviceInfo()
    }
}

struct ECGPayload: Codable {
    let data: [ECGDataPoint]
    let deviceInfo: DeviceInfo
    
    init(data: [ECGDataPoint]) {
        self.data = data
        self.deviceInfo = DeviceInfo()
    }
}

struct DeviceInfo: Codable {
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    
    init() {
        self.deviceModel = UIDevice.current.model
        self.osVersion = UIDevice.current.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
