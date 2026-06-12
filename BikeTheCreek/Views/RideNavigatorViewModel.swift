//
//  RideNavigatorViewModel.swift
//  BikeTheCreek
//

import MapKit
import SwiftUI

@MainActor
@Observable
final class RideNavigatorViewModel {

  // MARK: - Child managers

  let dataManager = MapDataManager()
  let session     = RideSessionManager()
  let location    = LocationManager()

  // MARK: - Map / camera state

  var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
  var cameraHeading: Double = 0

  // MARK: - Route overlay state

  private(set) var smoothPts: [CLLocationCoordinate2D] = []
  private(set) var markers: [OnLineMarker] = []

  // MARK: - UI state

  var routerOpen  = false
  var activeSheet: VisSheet?

  enum VisSheet: Identifiable {
    case sceneKit, playback
    var id: Int { hashValue }
  }

  // MARK: - Derived

  var sessionActive: Bool {
    session.isPreviewingRoute || session.isPreviewPaused || session.routePreviewCompleted
  }

  var arrowRotation: Double { location.userHeading - cameraHeading }

  var userCoordinate: CLLocationCoordinate2D { location.userLocation }

  var visualizationSamples: [WorkoutSample] {
    guard let route = dataManager.selectedRoute else { return [] }
    return Self.previewSamples(for: route)
  }

  var canVisualizeRoute: Bool { visualizationSamples.count > 1 }

  // MARK: - Lifecycle

  func onAppear() {
    session.prepareNavigation(for: dataManager.selectedRoute)
    fitRoute()
    refresh(dataManager.selectedRoute)
  }

  func onRouteChanged(_ route: BikeRoute?) {
    if session.isPreviewingRoute || session.isPreviewPaused || session.routePreviewCompleted {
      session.stopRoutePreview(clearPath: true)
    }
    session.prepareNavigation(for: route)
    fitRoute()
    refresh(route)
  }

  // MARK: - Camera

  func fitRoute() {
    guard let r = dataManager.selectedRoute else { return }
    withAnimation(.easeInOut(duration: 0.8)) {
      cameraPosition = .rect(r.mapRect)
    }
  }

  // MARK: - Route actions

  func toggleRouter() {
    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
      routerOpen.toggle()
    }
  }

  func startPreview() {
    withAnimation { session.startRoutePreview(route: dataManager.selectedRoute) }
  }

  func selectRoute(_ id: RideType) {
    withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
      dataManager.selectRide(id)
    }
    onRouteChanged(dataManager.selectedRoute)
  }

  // MARK: - Visualisation entry points

  func openSceneKit() { activeSheet = .sceneKit }
  func openPlayback() { activeSheet = .playback }

  // MARK: - Route overlay helpers

  func routeSegmentColor(_ route: BikeRoute) -> Color {
    switch route.id {
    case .leisure:  return .green
    case .family:   return Color(red: 0.2,  green: 0.75, blue: 0.55)
    case .bramalea: return Color.creek
    case .caledon:  return Color(red: 0.12, green: 0.58, blue: 0.48)
    case .regional: return Color.creekDeep
    }
  }

  var statusChipContent: (text: String, color: Color) {
    if session.isPreviewPaused       { return ("PAUSE", .orange) }
    if session.routePreviewCompleted { return ("DONE",  .green)  }
    return ("READY", .creek)
  }

  // MARK: - Private

  private func refresh(_ route: BikeRoute?) {
    smoothPts = []; markers = []
    guard let route else { return }
    Task.detached(priority: .userInitiated) {
      let (pts, mrk) = await RouteCache.shared.resolve(route)
      try? await Task.sleep(for: .milliseconds(32))
      await MainActor.run { [weak self] in
        self?.smoothPts = pts
        self?.markers   = mrk
      }
    }
  }

  private static func previewSamples(for route: BikeRoute) -> [WorkoutSample] {
    let maxSamples = 900
    let step = max(1, route.trackPoints.count / maxSamples)
    let points = stride(from: 0, to: route.trackPoints.count, by: step).map { route.trackPoints[$0] }
    guard points.count > 1 else { return [] }

    let start = Date()
    let nominalSpeed = max(route.distanceMeters / max(route.id.distanceInKm * 6.0 * 60.0, 1), 4.2)
    var elapsed: TimeInterval = 0
    var samples: [WorkoutSample] = []
    samples.reserveCapacity(points.count)

    for index in points.indices {
      if index > 0 {
        elapsed += points[index - 1].location.distance(from: points[index].location) / nominalSpeed
      }
      let progress = Double(index) / Double(points.count - 1)
      samples.append(WorkoutSample(
        coordinate: points[index],
        timestamp: start.addingTimeInterval(elapsed),
        heartRate: previewHeartRate(progress: progress, route: route),
        speed: nominalSpeed,
        altitude: previewAltitude(progress: progress, route: route),
        cadence: 78 + sin(progress * .pi * 8) * 8,
        power: 120 + Double(route.id.distanceInKm) * 1.5 + sin(progress * .pi * 5) * 28
      ))
    }
    return samples
  }

  private static func previewHeartRate(progress: Double, route: BikeRoute) -> Double {
    let effort = min(route.id.distanceInKm / 70, 1)
    return 112 + effort * 34 + sin(progress * .pi * 6) * 16 + progress * 18
  }

  private static func previewAltitude(progress: Double, route: BikeRoute) -> Double {
    let climb = route.id.distanceInKm * 0.9
    let rolling = sin(progress * .pi * 4) * 12 + sin(progress * .pi * 13) * 5
    return 185 + climb * progress + rolling
  }
}
