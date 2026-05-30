//
//  MapViewModel.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import Foundation
import Combine
import CoreLocation
import _MapKit_SwiftUI

@MainActor
class RideNavigatorViewModel: ObservableObject {
    @Published var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var smoothPts: [CLLocationCoordinate2D] = []
    @Published var markers: [OnLineMarker] = []
    @Published var mapHeading: Double = 0
    @Published var routerOpen: Bool = false
    
    // Shortcut Logic State
    @Published var shortcutPath: [CLLocationCoordinate2D] = []
    @Published var showShortcutSuggest: Bool = false
    @Published var isCalculatingShortcut: Bool = false
    
    private let dataManager: MapDataManager
    let session: RideSessionManager
    
    init(dataManager: MapDataManager, session: RideSessionManager) {
        self.dataManager = dataManager
        self.session = session
    }
    
    func refreshRoute() {
        guard let route = dataManager.selectedRoute else { return }
        smoothPts = []
        markers = []
        shortcutPath = []
        showShortcutSuggest = false
        
        Task {
            let (pts, mrk) = await RouteCache.shared.resolve(route)
            self.smoothPts = pts
            self.markers = mrk
        }
    }
    
    func fitRoute() {
        if let rect = dataManager.selectedRoute?.mapRect {
            position = .rect(rect)
        }
    }
    
    func evaluateShortcutEligibility() {
        guard session.isRecording, shortcutPath.isEmpty, !showShortcutSuggest,
              let route = dataManager.selectedRoute else { return }
        
        // Progress Logic: Time > 60% and Distance < 40%
        let estSeconds = parseDuration(route.id.durationLabel)
        let timeProgress = session.elapsedTime / estSeconds
        let distProgress = (session.totalDistance / 1000.0) / route.id.distanceInKm
        
        if timeProgress > 0.6 && distProgress < 0.4 {
            showShortcutSuggest = true
        }
    }
    

    private func parseDuration(_ label: String) -> Double {
        let low = label.lowercased().components(separatedBy: "-").first ?? "0"
        let val = Double(low.filter("0123456789.".contains)) ?? 0
        return label.contains("hr") ? val * 3600 : val * 60
    }
}
