//
//  OnLineMarker.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import Foundation
import CoreLocation

struct OnLineMarker: Identifiable {
  let id: Int
  let coordinate: CLLocationCoordinate2D
  let bearing: Double
}
