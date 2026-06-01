//
//  RideNavigatorViewModel.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-31.
//


//
//  RideNavigatorViewModel.swift
//  BikeTheCreek
//
//  Single source of truth for RideNavigatorView.
//  Owns: MapDataManager, RideSessionManager, LocationManager, all map/camera state.
//  View stays completely passive — reads and calls only what's exposed here.
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
    private(set) var cameraHeading: Double = 0

    // MARK: - Route overlay state

    private(set) var smoothPts: [CLLocationCoordinate2D] = []
    private(set) var markers:   [OnLineMarker]           = []

    // MARK: - UI state

    var routerOpen = false

    // MARK: - Derived

    var sessionActive: Bool { session.isPreviewingRoute || session.isRecording }

    /// Counter-rotated heading keeps the user arrow pointing true-north
    /// regardless of map rotation or pitch.
    var arrowRotation: Double { location.userHeading - cameraHeading }

    var userCoordinate: CLLocationCoordinate2D { location.userLocation }

    // MARK: - Lifecycle

    func onAppear() {
        session.prepareNavigation(for: dataManager.selectedRoute)
        fitRoute()
        refresh(dataManager.selectedRoute)
    }

    func onRouteChanged(_ route: BikeRoute?) {
        if session.isPreviewingRoute || session.routePreviewCompleted {
            session.stopRoutePreview(clearPath: true)
        }
        session.prepareNavigation(for: route)
        fitRoute()
        refresh(route)
        withAnimation { routerOpen = false }
    }

    // MARK: - Camera

    func onCameraChange(_ context: MapCameraUpdateContext) {
        cameraHeading = context.camera.heading
        if routerOpen { withAnimation { routerOpen = false } }
    }

    func fitRoute() {
        guard let r = dataManager.selectedRoute else { return }
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .rect(r.mapRect)
        }
    }

    // MARK: - Actions

    func toggleRouter() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            routerOpen.toggle()
        }
    }

    func startPreview() {
        withAnimation { session.startRoutePreview(route: dataManager.selectedRoute) }
    }

    func toggleRecording() {
        withAnimation {
            routerOpen = false
            session.toggleRecording(route: dataManager.selectedRoute)
        }
    }

    func selectRoute(_ id: RideType) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
            dataManager.selectRide(id)
        }
    }

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
        if session.isRecording           { return ("LIVE",  .red)   }
        if session.routePreviewCompleted { return ("DONE",  .green) }
        return ("READY", .creek)
    }

    // MARK: - Private

    private func refresh(_ route: BikeRoute?) {
        smoothPts = []; markers = []
        guard let route else { return }
        Task.detached(priority: .userInitiated) {
            let (pts, mrk) = await RouteCache.shared.resolve(route)
            await MainActor.run { [weak self] in
                self?.smoothPts = pts
                self?.markers   = mrk
            }
        }
    }
}
