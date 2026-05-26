//
//  RideSessionManager.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-25.
//


import Foundation
import CoreLocation
import Combine

@MainActor
class RideSessionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentSpeed: Double = 0.0 // m/s
    @Published var totalDistance: Double = 0.0 // meters
    @Published var currentElevation: Double = 0.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRecording: Bool = false
    @Published var userPath: [CLLocationCoordinate2D] = []
    @Published var currentLocation: CLLocation?
    @Published var heading: CLLocationDirection = 0
    @Published var navigationCue: NavigationCue?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isPreviewingRoute: Bool = false
    @Published var routePreviewCompleted: Bool = false

    private let locationManager = CLLocationManager()
    private var timer: AnyCancellable?
    private var routePreviewTimer: AnyCancellable?
    private var lastLocation: CLLocation?
    private var routeNavigator: RouteNavigator?
    private var activeRouteID: RideType?
    private var previewRoute: BikeRoute?
    private var previewIndex = 0
    private var previewStep = 1

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 3
        authorizationStatus = locationManager.authorizationStatus
        
        if !isUITesting {
            requestLocationAccess()
            locationManager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                locationManager.startUpdatingHeading()
            }
        }
    }

    func prepareNavigation(for route: BikeRoute?) {
        guard let route, activeRouteID != route.id else { return }
        activeRouteID = route.id
        routeNavigator = RouteNavigator(route: route)
        updateCue()
    }
    
    func startRecording(route: BikeRoute?) {
        stopRoutePreview(clearPath: true)
        prepareNavigation(for: route)
        isRecording = true
        routePreviewCompleted = false
        userPath = []
        totalDistance = 0
        elapsedTime = 0
        lastLocation = nil
        requestLocationAccess()
        locationManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        startTimer()
    }
    
    func stopRecording() {
        isRecording = false
        timer?.cancel()
        timer = nil
        lastLocation = nil
    }
    
    func toggleRecording(route: BikeRoute?) {
        if isRecording {
            stopRecording()
        } else {
            startRecording(route: route)
        }
    }
    
    func requestLocationAccess() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startRoutePreview(route: BikeRoute?) {
        guard let route, !route.trackPoints.isEmpty else { return }
        
        stopRecording()
        stopRoutePreview(clearPath: true)
        prepareNavigation(for: route)
        
        previewRoute = route
        previewIndex = 0
        previewStep = Swift.max(1, route.trackPoints.count / previewFrameCount)
        isPreviewingRoute = true
        routePreviewCompleted = false
        userPath = []
        totalDistance = 0
        elapsedTime = 0
        
        advanceRoutePreview()
        routePreviewTimer = Timer.publish(every: routePreviewInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.advanceRoutePreview()
            }
    }
    
    func stopRoutePreview(clearPath: Bool = false) {
        routePreviewTimer?.cancel()
        routePreviewTimer = nil
        isPreviewingRoute = false
        previewRoute = nil
        previewIndex = 0
        
        if clearPath {
            userPath = []
            totalDistance = 0
            elapsedTime = 0
            routePreviewCompleted = false
        }
    }

    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.elapsedTime += 1
            }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            heading = value
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            handleLocationUpdate(locations)
        }
    }
    
    private func handleLocationUpdate(_ locations: [CLLocation]) {
        guard !isPreviewingRoute else { return }
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        
        currentLocation = location
        currentSpeed = max(0, location.speed)
        currentElevation = location.altitude
        updateCue()
        
        guard isRecording, location.horizontalAccuracy <= 40 else { return }
        
        if let last = lastLocation {
            let distance = location.distance(from: last)
            if distance >= 2 {
                totalDistance += distance
                userPath.append(location.coordinate)
            }
        } else {
            userPath.append(location.coordinate)
        }
        
        lastLocation = location
    }
    
    private func updateCue() {
        guard let currentLocation, let routeNavigator else { return }
        navigationCue = routeNavigator.cue(for: currentLocation)
    }
    
    private func advanceRoutePreview() {
        guard let route = previewRoute else { return }
        
        if previewIndex >= route.trackPoints.count {
            completeRoutePreview(route: route)
            return
        }
        
        let coordinate = route.trackPoints[previewIndex]
        let location = CLLocation(
            coordinate: coordinate,
            altitude: currentElevation,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        currentLocation = location
        currentSpeed = 5.5
        elapsedTime += routePreviewInterval
        
        if let last = lastLocation {
            totalDistance += location.distance(from: last)
            heading = last.coordinate.bearing(to: coordinate)
        }
        
        lastLocation = location
        userPath.append(coordinate)
        updateCue()
        previewIndex += previewStep
    }
    
    private func completeRoutePreview(route: BikeRoute) {
        if let finish = route.trackPoints.last {
            currentLocation = CLLocation(latitude: finish.latitude, longitude: finish.longitude)
            if userPath.last != finish {
                userPath.append(finish)
            }
        }
        
        totalDistance = route.distanceMeters
        navigationCue = NavigationCue(
            direction: .finish,
            title: "Route preview complete",
            distanceMeters: 0,
            progress: 1
        )
        routePreviewCompleted = true
        stopRoutePreview()
    }
    
    private var routePreviewInterval: TimeInterval {
        isUITesting ? 0.015 : 0.12
    }
    
    private var previewFrameCount: Int {
        isUITesting ? 28 : 150
    }
    
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITESTING")
    }
}
