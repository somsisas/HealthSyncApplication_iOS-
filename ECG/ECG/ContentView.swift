import SwiftUI

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var networkService = NetworkService()
    
    var body: some View {
        ContentViewBody(healthKitManager: healthKitManager, networkService: networkService)
    }
}

struct ContentViewBody: View {
    @ObservedObject var healthKitManager: HealthKitManager
    @ObservedObject var networkService: NetworkService
    @StateObject private var syncManager: SyncManager
    
    init(healthKitManager: HealthKitManager, networkService: NetworkService) {
        self.healthKitManager = healthKitManager
        self.networkService = networkService
        _syncManager = StateObject(wrappedValue: SyncManager(
            healthKitManager: healthKitManager,
            networkService: networkService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Соменлон").foregroundStyle(Color(red: 0.3, green: 1.0, blue: 0.2))
                        .font(.system(size: 35))
                        .bold()
                    
                    // Authorization Section
                    authorizationSection
                    
                    // Sync Section
                    if healthKitManager.isAuthorized {
                        syncSection
                    }
                    
                    // Statistics Section
                    if let stats = syncManager.syncStats {
                        statisticsSection(stats: stats)
                    }
                    
                    // Error Display
                    if let error = syncManager.syncError {
                        errorSection(error: error)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Health Sync")
        }
    }
    
    // MARK: - Authorization Section
    
    private var authorizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Authorization")
                .font(.headline)
            
            if healthKitManager.isAuthorized {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Authorized to read health data")
                        .font(.subheadline)
                }
            } else {
                Button(action: {
                    Task {
                        try? await healthKitManager.requestAuthorization()
                    }
                }) {
                    HStack {
                        Image(systemName: "heart.text.square")
                        Text("Authorize HealthKit Access")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Sync Section
    
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Sync")
                .font(.headline)
            
            // Sync Status
            HStack {
                Image(systemName: syncManager.isSyncing ? "arrow.triangle.2.circlepath" : "cloud")
                    .symbolEffect(.pulse, isActive: syncManager.isSyncing)
                Text(healthKitManager.syncStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Last Sync Info
            if let lastSync = syncManager.lastSyncDate {
                HStack {
                    Image(systemName: "clock")
                    Text("Last synced: \(formatDate(lastSync))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Sync Button
            Button(action: {
                Task {
                    await syncManager.performSync()
                }
            }) {
                HStack {
                    if syncManager.isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(syncManager.isSyncing ? "Syncing..." : "Sync Now")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(syncManager.isSyncing ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(syncManager.isSyncing)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Statistics Section
    
    private func statisticsSection(stats: SyncStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Sync Results")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatCard(
                    title: "Heart Rate",
                    value: "\(stats.heartRateCount)",
                    icon: "heart.fill",
                    color: .red
                )
                
                StatCard(
                    title: "ECG",
                    value: "\(stats.ecgCount)",
                    icon: "waveform.path.ecg",
                    color: .blue
                )
            }
            
            Text(stats.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Error Section
    
    private func errorSection(error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

#Preview {
    ContentView()
}
