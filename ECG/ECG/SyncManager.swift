import Foundation
import Combine

class SyncManager: ObservableObject {
    private let healthKitManager: HealthKitManager
    private let networkService: NetworkService
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var syncStats: SyncStats?
    
    init(healthKitManager: HealthKitManager, networkService: NetworkService) {
        self.healthKitManager = healthKitManager
        self.networkService = networkService
        self.lastSyncDate = healthKitManager.getLastSyncDate()
    }
    
    // MARK: - Main Sync Function
    
    func performSync() async {
        await MainActor.run {
            self.isSyncing = true
            self.syncError = nil
            self.syncStats = nil
        }
        
        do {
            // Get the date range for sync
            let startDate = healthKitManager.getLastSyncDate()
            let endDate = Date()
            
            print("Starting sync from \(startDate) to \(endDate)")
            
            // Fetch heart rate data
            let heartRateData = try await healthKitManager.fetchHeartRateData(from: startDate, to: endDate)
            print("Fetched \(heartRateData.count) heart rate samples")
            
            // Fetch ECG data
            let ecgData = try await healthKitManager.fetchECGData(from: startDate, to: endDate)
            print("Fetched \(ecgData.count) ECG recordings")
            
            // Sync heart rate data if any
            if !heartRateData.isEmpty {
                try await networkService.syncHeartRateData(heartRateData)
                print("Synced heart rate data successfully")
            }
            
            // Sync ECG data if any
            if !ecgData.isEmpty {
                try await networkService.syncECGData(ecgData)
                print("Synced ECG data successfully")
            }
            
            // Update last sync date
            healthKitManager.updateLastSyncDate()
            
            // Update UI
            await MainActor.run {
                self.lastSyncDate = Date()
                self.syncStats = SyncStats(
                    heartRateCount: heartRateData.count,
                    ecgCount: ecgData.count,
                    dateRange: (startDate, endDate)
                )
                self.isSyncing = false
                self.healthKitManager.syncStatus = "Synced successfully at \(self.formatDate(Date()))"
            }
            
        } catch {
            await MainActor.run {
                self.syncError = error.localizedDescription
                self.isSyncing = false
                self.healthKitManager.syncStatus = "Sync failed: \(error.localizedDescription)"
            }
            print("Sync error: \(error)")
        }
    }
    
    // MARK: - Background Sync Setup
    
    func scheduleBackgroundSync() {
        // This would use Background Tasks framework
        // For research purposes, you might just run manual syncs or daily syncs
        print("Background sync scheduling - implement with BGTaskScheduler for production")
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Sync Statistics

struct SyncStats {
    let heartRateCount: Int
    let ecgCount: Int
    let dateRange: (start: Date, end: Date)
    
    var summary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return """
        Synced Data:
        • \(heartRateCount) heart rate samples
        • \(ecgCount) ECG recordings
        
        Period: \(formatter.string(from: dateRange.start)) to \(formatter.string(from: dateRange.end))
        """
    }
}
