//
//  RouteCache.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import Foundation
import CoreLocation

actor RouteCache {
  static let shared = RouteCache()
  private var smooth:  [RideType: [CLLocationCoordinate2D]] = [:]
  private var markers: [RideType: [OnLineMarker]]           = [:]
  
  func resolve(_ r: BikeRoute) -> ([CLLocationCoordinate2D], [OnLineMarker]) {
    let pts: [CLLocationCoordinate2D]
    if let c = smooth[r.id] { pts = c }
    else { pts = PathGeometry.simplifyPath(r.trackPoints, epsilon: 0.00004); smooth[r.id] = pts }
    
    let mrk: [OnLineMarker]
    if let c = markers[r.id] { mrk = c }
    else { mrk = PathGeometry.buildMarkers(pts); markers[r.id] = mrk }
    
    return (pts, mrk)
  }
}
