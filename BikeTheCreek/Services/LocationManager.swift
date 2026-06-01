//
//  LocationManager.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-31.
//
import Foundation
import CoreLocation
import UIKit

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
  @ObservationIgnored let manager = CLLocationManager()
  var userHeading: CLLocationDirection = 0.0
  var userLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
  var userLocations: [CLLocationCoordinate2D] = []
  
  override init() {
    super.init()
    manager.delegate = self
    startLocationServices()
  }
  
  deinit {
    manager.stopUpdatingLocation()
    manager.stopUpdatingHeading()
  }
  
  func headingOrientation() -> CLDeviceOrientation {
    var deviceOrientation: UIDeviceOrientation = .portrait
    
    Task { @MainActor in
      deviceOrientation = UIDevice.current.orientation
    }
    
    switch deviceOrientation {
    case .portrait:
      return .portrait
    case .portraitUpsideDown:
      return .portraitUpsideDown
    case .landscapeLeft:
      return .landscapeRight
    case .landscapeRight:
      return .landscapeLeft
    default:
      return .portrait
    }
  }
  
  func startLocationServices() {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      manager.desiredAccuracy = kCLLocationAccuracyBest
      manager.allowsBackgroundLocationUpdates = true
      manager.headingOrientation = headingOrientation()
      manager.startUpdatingLocation()
      manager.startUpdatingHeading()
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    case .denied:
      print("Location access denied")
    case .restricted:
      print("Location access restricted")
    @unknown default:
      print("Unknown authorization status")
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    userLocation = location.coordinate
    userLocations.append(location.coordinate)
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    guard newHeading.headingAccuracy >= 0 else { return }
    
    let heading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
    userHeading = heading
  }
  
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    startLocationServices()
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Location manager error: \(error.localizedDescription)")
  }
}
