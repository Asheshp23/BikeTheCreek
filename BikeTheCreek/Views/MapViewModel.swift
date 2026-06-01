//
//  MapMeViewModel.swift
//
//  Owns LocationManager + all map state.
//  View stays completely passive — binds only to this object.
//
import Combine
import MapKit
import SwiftUI

@MainActor
@Observable
final class MapMeViewModel {
  
  // MARK: - Dependencies
  
  private(set) var locationManager = LocationManager()
  
  // MARK: - Map camera
  
  /// Keeps the map centred on the user with heading-up orientation.
  var cameraPosition: MapCameraPosition = .userLocation(
    followsHeading: true,
    fallback: .automatic
  )
  
  /// Live heading of the map camera — used to counter-rotate the user arrow
  /// so it always points in the true travel direction regardless of map tilt/rotate.
  private(set) var cameraHeading: Double = 0.0
  
  // MARK: - Derived / convenience
  
  /// Current user coordinate (falls back to a safe zero if unavailable).
  var userCoordinate: CLLocationCoordinate2D {
    locationManager.userLocation
  }
  
  /// Breadcrumb trail the user has travelled.
  var userPath: [CLLocationCoordinate2D] {
    locationManager.userLocations
  }
  
  /// Rotation angle for the direction arrow:
  /// device heading minus camera heading keeps the chevron route-aligned
  /// even when the map is rotated or pitched.
  var arrowRotation: Double {
    locationManager.userHeading - cameraHeading
  }
  
  // MARK: - Camera change handler
  
  /// Call this from `.onMapCameraChange` in the view.
  func onCameraChange(_ context: MapCameraUpdateContext) {
    cameraHeading = context.camera.heading
  }
  
  // MARK: - Actions
  
  /// Re-centre the camera on the user's current location.
  func recentre() {
    withAnimation(.easeInOut(duration: 0.6)) {
      cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
    }
  }
}
