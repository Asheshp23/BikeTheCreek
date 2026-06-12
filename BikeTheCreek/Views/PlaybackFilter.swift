//
//  PlaybackFilter.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-06-06.
//


//
//  MapFilterPlaybackView.swift
//  BikeTheCreek
//
//  Custom map playback with real-time filter controls.
//  Filters: metric threshold, HR zone, speed range, time window.
//  Filtered segments render as a highlighted overlay on the base route.
//

import MapKit
import SwiftUI

// MARK: - Filter model

struct PlaybackFilter {
    var activeZones:   Set<HRZone>  = Set(HRZone.allCases)
    var minSpeed:      Double       = 0      // km/h
    var maxSpeed:      Double       = 60
    var minHR:         Double       = 0      // bpm
    var maxHR:         Double       = 220
    var showOnlyFilter: Bool        = false  // dim base route

    func matches(_ sample: WorkoutSample) -> Bool {
        let hrOK = sample.heartRate.map {
            activeZones.contains(HRZone.zone(for: $0)) &&
            $0 >= minHR && $0 <= maxHR
        } ?? true
        let spOK = sample.speed.map { $0 >= minSpeed && $0 <= maxSpeed } ?? true
        return hrOK && spOK
    }
}

// MARK: - View

struct MapFilterPlaybackView: View {

    let samples: [WorkoutSample]
    @State private var vm: MapFilterPlaybackViewModel

    init(samples: [WorkoutSample]) {
        self.samples = samples
        _vm = State(initialValue: MapFilterPlaybackViewModel(samples: samples))
    }

    var body: some View {
        ZStack {
            mapLayer
            VStack {
                Spacer()
                filterPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }
        }
        .navigationTitle("Filter Playback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { withAnimation { vm.resetFilters() } }
                    .foregroundStyle(Color.creek)
            }
        }
        .sheet(isPresented: $vm.showAdvanced) {
            advancedFilters
                .presentationDetents([.medium])
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $vm.cameraPosition) {
            // Base route (dimmed when filter active)
            if vm.allCoords.count > 1 {
                MapPolyline(coordinates: vm.allCoords)
                    .stroke(
                        Color.white.opacity(vm.filter.showOnlyFilter ? 0.08 : 0.25),
                        lineWidth: 3)
            }

            // Filtered segments — grouped into contiguous runs for clean rendering
            ForEach(vm.filteredRuns) { run in
                MapPolyline(coordinates: run.coords)
                    .stroke(Color(run.color), lineWidth: 5)
            }

            // Playhead dot
            if let s = vm.currentSample {
                Annotation("", coordinate: s.coordinate, anchor: .center) {
                    Circle()
                        .fill(vm.dotColor)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted,
                            pointsOfInterest: .excludingAll))
        .ignoresSafeArea()
    }

    // MARK: - Filter panel

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Zone toggles
            HStack(spacing: 6) {
                Text("ZONES").font(.f(9, .black)).foregroundStyle(Color.white.opacity(0.4)).tracking(1.2)
                Spacer()
                Button("Advanced") { vm.showAdvanced = true }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.creek)
            }

            HStack(spacing: 6) {
                ForEach(HRZone.allCases, id: \.rawValue) { zone in
                    let active = vm.filter.activeZones.contains(zone)
                    Button {
                        withAnimation { vm.toggleZone(zone) }
                    } label: {
                        Text("Z\(zone.rawValue+1)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(active ? .white : Color.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(active ? Color(zone.color).opacity(0.8) : Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            // Dim-base toggle + stat summary
            HStack {
                Toggle(isOn: $vm.filter.showOnlyFilter) {
                    Text("Highlight only").font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                }
                .tint(.creek)
                Spacer()
                Text(vm.filterSummary)
                    .font(.mono(10))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Advanced filters sheet

    private var advancedFilters: some View {
        NavigationStack {
            Form {
                Section("Speed (km/h)") {
                    LabeledContent("Min: \(Int(vm.filter.minSpeed))") {
                        Slider(value: $vm.filter.minSpeed, in: 0...vm.filter.maxSpeed)
                    }
                    LabeledContent("Max: \(Int(vm.filter.maxSpeed))") {
                        Slider(value: $vm.filter.maxSpeed, in: vm.filter.minSpeed...60)
                    }
                }
                Section("Heart Rate (bpm)") {
                    LabeledContent("Min: \(Int(vm.filter.minHR))") {
                        Slider(value: $vm.filter.minHR, in: 0...vm.filter.maxHR)
                    }
                    LabeledContent("Max: \(Int(vm.filter.maxHR))") {
                        Slider(value: $vm.filter.maxHR, in: vm.filter.minHR...220)
                    }
                }
            }
            .navigationTitle("Advanced Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { vm.showAdvanced = false }
                }
            }
        }
    }
}

// MARK: - Filtered run

struct FilteredRun: Identifiable {
    let id     = UUID()
    let coords : [CLLocationCoordinate2D]
    let color  : UIColor
}

// MARK: - ViewModel

@MainActor
@Observable
final class MapFilterPlaybackViewModel {

    private let samples: [WorkoutSample]
    let allCoords: [CLLocationCoordinate2D]

    var filter        = PlaybackFilter()
    var showAdvanced  = false
    var cameraPosition: MapCameraPosition = .automatic

    private(set) var filteredRuns: [FilteredRun] = []
    private(set) var currentSample: WorkoutSample?

    init(samples: [WorkoutSample]) {
        self.samples   = samples
        self.allCoords = samples.map(\.coordinate)
        if let bbox = makeBBox(samples) { cameraPosition = .region(bbox) }
        recompute()
    }

    // MARK: Derived

    var dotColor: Color {
        guard let hr = currentSample?.heartRate else { return .creek }
        return Color(HRZone.zone(for: hr).color)
    }

    var filterSummary: String {
        let total    = samples.count
        let filtered = samples.filter { filter.matches($0) }.count
        guard total > 0 else { return "" }
        return "\(Int(Double(filtered)/Double(total)*100))% match"
    }

    // MARK: Actions

    func toggleZone(_ zone: HRZone) {
        if filter.activeZones.contains(zone) { filter.activeZones.remove(zone) }
        else                                 { filter.activeZones.insert(zone) }
        recompute()
    }

    func resetFilters() {
        filter = PlaybackFilter()
        recompute()
    }

    // MARK: - Recompute filtered runs

    func recompute() {
        var runs: [FilteredRun] = []
        var current: [CLLocationCoordinate2D] = []
        var currentColor: UIColor = HRZone.zone1.color

        for s in samples {
            if filter.matches(s) {
                let c = s.heartRate.map { HRZone.zone(for: $0).color } ?? HRZone.zone1.color
                if current.isEmpty || c == currentColor {
                    current.append(s.coordinate)
                    currentColor = c
                } else {
                    if current.count > 1 { runs.append(FilteredRun(coords: current, color: currentColor)) }
                    current = [s.coordinate]
                    currentColor = c
                }
            } else {
                if current.count > 1 { runs.append(FilteredRun(coords: current, color: currentColor)) }
                current = []
            }
        }
        if current.count > 1 { runs.append(FilteredRun(coords: current, color: currentColor)) }
        filteredRuns = runs
        currentSample = samples.last(where: { filter.matches($0) })
    }

    private func makeBBox(_ samples: [WorkoutSample]) -> MKCoordinateRegion? {
        guard !samples.isEmpty else { return nil }
        let lats = samples.map { $0.coordinate.latitude  }
        let lons = samples.map { $0.coordinate.longitude }
        let center = CLLocationCoordinate2D(
            latitude:  (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta:  (lats.max()! - lats.min()!) * 1.4,
            longitudeDelta: (lons.max()! - lons.min()!) * 1.4)
        return MKCoordinateRegion(center: center, span: span)
    }
}
