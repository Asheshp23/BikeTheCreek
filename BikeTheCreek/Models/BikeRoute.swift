import Foundation
import CoreLocation
import MapKit
import SwiftUI

enum RideType: String, CaseIterable, Identifiable {
  case leisure = "Leisure Ride - 6km"
  case family = "Family Ride - 14 km"
  case bramalea = "Bramalea Ride - 36km"
  case caledon = "Caledon Town Ride - 66km"
  case regional = "Regional Ride 69 Km"
  
  var id: String { self.rawValue }
  
  var lineStringFile: String { "Layer 2026 Bike the Creek \(self.rawValue)-LINESTRING" }
  var pointFile: String { "Layer 2026 Bike the Creek \(self.rawValue)-POINT" }
  
  var shortName: String {
    switch self {
    case .leisure: "Leisure"
    case .family: "Family"
    case .bramalea: "Bramalea"
    case .caledon: "Caledon"
    case .regional: "Regional"
    }
  }
  
  var distanceLabel: String {
    switch self {
    case .leisure: "6 km"
    case .family: "14 km"
    case .bramalea: "36 km"
    case .caledon: "66 km"
    case .regional: "69 km"
    }
  }
  
  var durationLabel: String {
    switch self {
    case .leisure: "30-60 min"
    case .family: "1.5-2 hr"
    case .bramalea: "2.5-3 hr"
    case .caledon: "3.5-4.5 hr"
    case .regional: "4-4.5 hr"
    }
  }
  
  var accentColor: Color {
    switch self {
    case .leisure: .green
    case .family: .teal
    case .bramalea: .orange
    case .caledon: .purple
    case .regional: .red
    }
  }
  
  var routeCardAccessibilityID: String {
    "route-card-\(shortName.lowercased())"
  }
}

extension RideType {
  var distanceInKm: Double {
    switch self {
    case .leisure: return 6.0
    case .family: return 14.0
    case .bramalea: return 36.0
    case .caledon: return 66.0
    case .regional: return 69.0
    }
  }
}

struct BikeRoute: Identifiable, Equatable, Hashable {
  let id: RideType
  let name: String
  let trackPoints: [CLLocationCoordinate2D]
  let waypoints: [BikeWaypoint]
  
  static func == (lhs: BikeRoute, rhs: BikeRoute) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
  
  var distanceMeters: CLLocationDistance {
    trackPoints.totalDistance()
  }
  
  var displayDistance: String {
    if distanceMeters > 0 {
      return String(format: "%.1f km", distanceMeters / 1000)
    }
    return id.distanceLabel
  }
  
  var mapRect: MKMapRect {
    trackPoints.boundingMapRect(paddingMultiplier: 0.16)
  }
  
  var routeStops: [BikeWaypoint] {
    waypoints.filter { $0.type == .start || $0.type == .finish }
  }
  
  var directionArrows: [RouteDirectionArrow] {
    trackPoints.directionArrows(preferredCount: 18)
  }
}

struct RouteDirectionArrow: Identifiable, Equatable {
  let id: Int
  let coordinate: CLLocationCoordinate2D
  let bearing: CLLocationDirection
}

struct BikeWaypoint: Identifiable, Equatable, Hashable {
  let id: String
  let name: String
  let coordinate: CLLocationCoordinate2D
  let type: WaypointType
  
  init(id: String = UUID().uuidString, name: String, coordinate: CLLocationCoordinate2D, type: WaypointType) {
    self.id = id
    self.name = name
    self.coordinate = coordinate
    self.type = type
  }
  
  static func == (lhs: BikeWaypoint, rhs: BikeWaypoint) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum WaypointType: String, CaseIterable, Codable, Hashable {
  case start, finish, pavilion, water, firstAid, junction, general
  
  var systemImage: String {
    switch self {
    case .start: "flag.fill"
    case .finish: "flag.checkered"
    case .pavilion: "tent.fill"
    case .water: "drop.fill"
    case .firstAid: "cross.case.fill"
    case .junction: "mappin.and.ellipse"
    case .general: "circle.fill"
    }
  }
  
  var color: Color {
    switch self {
    case .start: .green
    case .finish: .red
    case .pavilion: .brown
    case .water: .cyan
    case .firstAid: .red
    case .junction: .blue
    case .general: .secondary
    }
  }
}

struct NavigationCue: Equatable {
  enum Direction: Equatable {
    case start
    case continueStraight
    case slightLeft
    case left
    case sharpLeft
    case slightRight
    case right
    case sharpRight
    case offRoute
    case finish
  }
  
  let direction: Direction
  let title: String
  let distanceMeters: CLLocationDistance
  let progress: Double
  
  var distanceLabel: String {
    if distanceMeters >= 1000 {
      return String(format: "%.1f km", distanceMeters / 1000)
    }
    return "\(Int(distanceMeters.rounded())) m"
  }
  
  var systemImage: String {
    switch direction {
    case .start: "play.fill"
    case .continueStraight: "arrow.up"
    case .slightLeft: "arrow.up.left"
    case .left: "arrow.turn.up.left"
    case .sharpLeft: "arrow.uturn.left"
    case .slightRight: "arrow.up.right"
    case .right: "arrow.turn.up.right"
    case .sharpRight: "arrow.uturn.right"
    case .offRoute: "exclamationmark.triangle.fill"
    case .finish: "flag.checkered"
    }
  }
}

extension Array where Element == CLLocationCoordinate2D {
  func totalDistance() -> CLLocationDistance {
    guard count > 1 else { return 0 }
    
    return zip(self, dropFirst()).reduce(0) { partial, pair in
      partial + pair.0.location.distance(from: pair.1.location)
    }
  }
  
  func boundingMapRect(paddingMultiplier: Double = 0.12) -> MKMapRect {
    guard let first = first else { return MKMapRect.world }
    
    let points = map(MKMapPoint.init)
    let initial = MKMapRect(origin: MKMapPoint(first), size: MKMapSize(width: 1, height: 1))
    let rect = points.reduce(initial) { partial, point in
      partial.union(MKMapRect(origin: point, size: MKMapSize(width: 1, height: 1)))
    }
    
    let paddingX = Swift.max(rect.size.width * paddingMultiplier, 900)
    let paddingY = Swift.max(rect.size.height * paddingMultiplier, 900)
    return rect.insetBy(dx: -paddingX, dy: -paddingY)
  }
  
  func directionArrows(preferredCount: Int) -> [RouteDirectionArrow] {
    guard count > 2 else { return [] }
    
    let total = totalDistance()
    guard total > 0 else { return [] }
    
    let arrowCount = Swift.max(4, Swift.min(preferredCount, Int(total / 850)))
    let spacing = total / Double(arrowCount + 1)
    var arrows: [RouteDirectionArrow] = []
    var nextTarget = spacing
    var travelled: CLLocationDistance = 0
    
    for index in 0..<(count - 1) {
      let start = self[index]
      let end = self[index + 1]
      let segmentDistance = start.location.distance(from: end.location)
      
      while nextTarget <= travelled + segmentDistance {
        let fraction = segmentDistance == 0 ? 0 : (nextTarget - travelled) / segmentDistance
        let coordinate = interpolatedCoordinate(from: start, to: end, fraction: fraction)
        arrows.append(
          RouteDirectionArrow(
            id: arrows.count,
            coordinate: coordinate,
            bearing: start.bearing(to: end)
          )
        )
        nextTarget += spacing
      }
      
      travelled += segmentDistance
    }
    
    return arrows
  }
  
  private func interpolatedCoordinate(
    from start: CLLocationCoordinate2D,
    to end: CLLocationCoordinate2D,
    fraction: Double
  ) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(
      latitude: start.latitude + (end.latitude - start.latitude) * fraction,
      longitude: start.longitude + (end.longitude - start.longitude) * fraction
    )
  }
}

extension CLLocationCoordinate2D {
  var location: CLLocation {
    CLLocation(latitude: latitude, longitude: longitude)
  }
  
  func bearing(to coordinate: CLLocationCoordinate2D) -> CLLocationDirection {
    let startLat = latitude * .pi / 180
    let startLon = longitude * .pi / 180
    let endLat = coordinate.latitude * .pi / 180
    let endLon = coordinate.longitude * .pi / 180
    let deltaLon = endLon - startLon
    
    let y = sin(deltaLon) * cos(endLat)
    let x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(deltaLon)
    return atan2(y, x) * 180 / .pi
  }
}

// Fix for CLLocationCoordinate2D not being Hashable
extension CLLocationCoordinate2D: @retroactive Equatable {}
extension CLLocationCoordinate2D: @retroactive Hashable {
  public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
  }
  public func hash(into hasher: inout Hasher) {
    hasher.combine(latitude)
    hasher.combine(longitude)
  }
}
