import Foundation
import SwiftUI
import Network

/// Manages offline reading queue for syncing when network becomes available
@MainActor
class OfflineQueue: ObservableObject {
    static let shared = OfflineQueue()

    @Published var pendingReadings: [PendingReading] = []
    @Published var isSyncing = false
    @Published var syncError: String?

    private let queueKey = "meterscience_offline_queue"
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    struct PendingReading: Codable, Identifiable {
        let id: UUID
        let meterId: UUID
        let rawValue: String
        let normalizedValue: String
        let confidence: Float
        let imageData: Data?
        let latitude: Double?
        let longitude: Double?
        let createdAt: Date

        init(meterId: UUID, rawValue: String, normalizedValue: String, confidence: Float, imageData: Data? = nil, latitude: Double? = nil, longitude: Double? = nil) {
            self.id = UUID()
            self.meterId = meterId
            self.rawValue = rawValue
            self.normalizedValue = normalizedValue
            self.confidence = confidence
            self.imageData = imageData
            self.latitude = latitude
            self.longitude = longitude
            self.createdAt = Date()
        }
    }

    private init() {
        loadFromDisk()
        startNetworkMonitoring()
    }

    // MARK: - Public Methods

    /// Queue a reading for offline storage
    func queueReading(_ reading: PendingReading) {
        pendingReadings.append(reading)
        saveToDisk()

        // Try to sync immediately if online
        Task {
            await syncPendingReadings()
        }
    }

    /// Sync all pending readings to the server
    func syncPendingReadings() async {
        guard !isSyncing else { return }
        guard !pendingReadings.isEmpty else { return }
        guard AuthManager.shared.isAuthenticated else { return }

        isSyncing = true
        syncError = nil

        var successfullyUploaded: [UUID] = []

        for reading in pendingReadings {
            do {
                _ = try await APIService.shared.createReading(
                    meterId: reading.meterId,
                    rawValue: reading.rawValue,
                    normalizedValue: reading.normalizedValue,
                    confidence: reading.confidence,
                    source: "offline_queue",
                    latitude: reading.latitude,
                    longitude: reading.longitude
                )
                successfullyUploaded.append(reading.id)
                print("Successfully synced offline reading: \(reading.id)")
            } catch {
                print("Failed to sync reading \(reading.id): \(error)")
                syncError = "Some readings failed to sync"
                // Continue with other readings
            }
        }

        // Remove successfully uploaded readings
        if !successfullyUploaded.isEmpty {
            pendingReadings.removeAll { successfullyUploaded.contains($0.id) }
            saveToDisk()
        }

        isSyncing = false
    }

    /// Delete a specific pending reading
    func deletePendingReading(_ id: UUID) {
        pendingReadings.removeAll { $0.id == id }
        saveToDisk()
    }

    /// Clear all pending readings (use with caution)
    func clearQueue() {
        pendingReadings.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            pendingReadings = try decoder.decode([PendingReading].self, from: data)
            print("Loaded \(pendingReadings.count) pending readings from disk")
        } catch {
            print("Failed to load offline queue: \(error)")
            pendingReadings = []
        }
    }

    func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(pendingReadings)
            UserDefaults.standard.set(data, forKey: queueKey)
            print("Saved \(pendingReadings.count) pending readings to disk")
        } catch {
            print("Failed to save offline queue: \(error)")
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                // Network became available, try to sync
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
                    await self?.syncPendingReadings()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
}

// MARK: - Offline Queue View

struct OfflineQueueView: View {
    @StateObject private var queue = OfflineQueue.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if queue.pendingReadings.isEmpty {
                    EmptyQueueView()
                } else {
                    List {
                        if let error = queue.syncError {
                            Section {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Section {
                            ForEach(queue.pendingReadings) { reading in
                                PendingReadingRow(reading: reading)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    queue.deletePendingReading(queue.pendingReadings[index].id)
                                }
                            }
                        } header: {
                            HStack {
                                Text("Pending (\(queue.pendingReadings.count))")
                                Spacer()
                                if queue.isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        } footer: {
                            Text("These readings will automatically sync when you're online")
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Offline Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if !queue.pendingReadings.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task {
                                await queue.syncPendingReadings()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync")
                            }
                        }
                        .disabled(queue.isSyncing)
                    }
                }
            }
        }
    }
}

struct PendingReadingRow: View {
    let reading: OfflineQueue.PendingReading

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(reading.normalizedValue)
                    .font(.headline)

                Spacer()

                Image(systemName: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 12) {
                Label(formatDate(reading.createdAt), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(Int(reading.confidence * 100))%", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(confidenceColor(reading.confidence))

                if reading.latitude != nil && reading.longitude != nil {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence >= 0.9 {
            return .green
        } else if confidence >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

struct EmptyQueueView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("All Synced")
                    .font(.title2.bold())

                Text("No pending readings in the offline queue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Readings taken offline will appear here until synced")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

#Preview {
    OfflineQueueView()
}
