import SwiftUI
internal import HealthKit

struct WorkoutPickerSheet: View {
  let manager: WorkoutDataManager
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationStack {
      List {
        healthKitSection
        fileImportSection
        loadingSection
        recentRidesSection
        errorSection
      }
      .navigationTitle("Load Workout")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
  
  private var healthKitSection: some View {
    Section {
      Button {
        Task { await manager.loadHealthKitWorkouts() }
      } label: {
        Label("Load from HealthKit", systemImage: "heart.fill")
      }
      .disabled(manager.isLoading)
    } header: {
      Text("Apple Health")
    }
  }
  
  private var fileImportSection: some View {
    Section {
      FileImportRow(manager: manager)
    } header: {
      Text("Import File (GPX / FIT)")
    }
  }
  
  @ViewBuilder
  private var loadingSection: some View {
    if manager.isLoading {
      HStack {
        Spacer()
        ProgressView().tint(.creek)
        Spacer()
      }
    }
  }
  
  @ViewBuilder
  private var recentRidesSection: some View {
    if !manager.workouts.isEmpty {
      Section("Recent Rides") {
        ForEach(manager.workouts, id: \.uuid) { workout in
          workoutButton(workout)
        }
      }
    }
  }
  
  @ViewBuilder
  private var errorSection: some View {
    if let error = manager.error {
      Section {
        Text(error)
          .foregroundStyle(.red)
          .font(.caption)
      }
    }
  }
  
  private func workoutButton(_ workout: HKWorkout) -> some View {
    Button {
      Task {
        await manager.loadSamples(for: workout)
        dismiss()
      }
    } label: {
      VStack(alignment: .leading, spacing: 3) {
        Text(workout.startDate, style: .date)
          .font(.system(size: 14, weight: .semibold))
        Text(workoutSummary(for: workout))
          .font(.mono(11))
          .foregroundStyle(.secondary)
      }
    }
  }
  
  private func workoutSummary(for workout: HKWorkout) -> String {
    let distance = workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0
    let duration = Duration.seconds(workout.duration).formatted(.time(pattern: .hourMinute))
    return String(format: "%.1f km · %@", distance, duration)
  }
}

private struct FileImportRow: View {
  let manager: WorkoutDataManager
  @State private var showImporter = false
  
  var body: some View {
    Button {
      showImporter = true
    } label: {
      Label("Choose GPX or FIT file", systemImage: "doc.badge.plus")
    }
    .fileImporter(
      isPresented: $showImporter,
      allowedContentTypes: [.init(filenameExtension: "gpx")!, .init(filenameExtension: "fit")!],
      allowsMultipleSelection: false
    ) { result in
      guard case .success(let urls) = result, let url = urls.first else { return }
      Task { await manager.importFile(url: url) }
    }
  }
}
