import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var syncStatus = "Not synced"
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        // Define the data types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.electrocardiogramType()
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        
        await MainActor.run {
            self.isAuthorized = true
        }
    }
    
    // MARK: - Heart Rate Data Extraction
    
    func fetchHeartRateData(from startDate: Date, to endDate: Date) async throws -> [HeartRateDataPoint] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let dataPoints = samples.map { sample in
                    HeartRateDataPoint(
                        timestamp: sample.startDate,
                        heartRate: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                        sourceDevice: sample.sourceRevision.productType ?? "Unknown",
                        metadata: sample.metadata
                    )
                }
                
                continuation.resume(returning: dataPoints)
            }
            
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - ECG Data Extraction
    
    func fetchECGData(from startDate: Date, to endDate: Date) async throws -> [ECGDataPoint] {
        let ecgType = HKObjectType.electrocardiogramType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: ecgType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let ecgSamples = samples as? [HKElectrocardiogram] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Process each ECG sample
                Task {
                    var ecgDataPoints: [ECGDataPoint] = []
                    
                    for ecgSample in ecgSamples {
                        let voltageData = try await self.extractVoltageData(from: ecgSample)
                        
                        let dataPoint = ECGDataPoint(
                            timestamp: ecgSample.startDate,
                            classification: ecgSample.classification.rawValue,
                            averageHeartRate: ecgSample.averageHeartRate?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                            samplingFrequency: ecgSample.samplingFrequency?.doubleValue(for: .hertz()),
                            voltageMeasurements: voltageData,
                            symptomStatus: ecgSample.symptomsStatus.rawValue
                        )
                        
                        ecgDataPoints.append(dataPoint)
                    }
                    
                    continuation.resume(returning: ecgDataPoints)
                }
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func extractVoltageData(from ecg: HKElectrocardiogram) async throws -> [VoltageMeasurement] {
        return try await withCheckedThrowingContinuation { continuation in
            var measurements: [VoltageMeasurement] = []
            
            let query = HKElectrocardiogramQuery(ecg) { query, result in
                switch result {
                case .measurement(let voltageMeasurement):
                    let measurement = VoltageMeasurement(
                        timeSinceStart: voltageMeasurement.timeSinceSampleStart,
                        voltage: voltageMeasurement.quantity(for: .appleWatchSimilarToLeadI)?.doubleValue(for: .volt())
                    )
                    measurements.append(measurement)
                    
                case .done:
                    continuation.resume(returning: measurements)
                    
                case .error(let error):
                    continuation.resume(throwing: error)
                    
                @unknown default:
                    break
                }
            }
            
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Get Last Sync Date
    
    func getLastSyncDate() -> Date {
        if let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            return lastSync
        }
        // Default to 7 days ago if never synced
        return Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }
    
    func updateLastSyncDate() {
        UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
    }
}

// MARK: - Data Models

struct HeartRateDataPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let heartRate: Double
    let sourceDevice: String
    let metadataJSON: String?
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, heartRate, sourceDevice, metadataJSON
    }
    
    init(timestamp: Date, heartRate: Double, sourceDevice: String, metadata: [String: Any]?) {
        self.id = UUID()
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.sourceDevice = sourceDevice
        
        // Convert metadata to JSON string
        if let metadata = metadata,
           let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.metadataJSON = jsonString
        } else {
            self.metadataJSON = nil
        }
    }
}

struct ECGDataPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let classification: Int
    let averageHeartRate: Double?
    let samplingFrequency: Double?
    let voltageMeasurements: [VoltageMeasurement]
    let symptomStatus: Int
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, classification, averageHeartRate, samplingFrequency, voltageMeasurements, symptomStatus
    }
    
    init(timestamp: Date, classification: Int, averageHeartRate: Double?, samplingFrequency: Double?, voltageMeasurements: [VoltageMeasurement], symptomStatus: Int) {
        self.id = UUID()
        self.timestamp = timestamp
        self.classification = classification
        self.averageHeartRate = averageHeartRate
        self.samplingFrequency = samplingFrequency
        self.voltageMeasurements = voltageMeasurements
        self.symptomStatus = symptomStatus
    }
}

struct VoltageMeasurement: Codable {
    let timeSinceStart: TimeInterval
    let voltage: Double?
}

// MARK: - Errors

enum HealthKitError: Error {
    case notAvailable
    case dataTypeNotAvailable
    case authorizationDenied
}
