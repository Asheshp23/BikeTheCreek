//
//  PathGeometry.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import CoreLocation

struct PathGeometry {
  
  /// Simplifies a path using the Ramer-Douglas-Peucker (RDP) algorithm.
  /// - Parameters:
  ///   - points: The array of coordinates to simplify.
  ///   - epsilon: The tolerance level. Higher values result in more aggressive simplification.
  /// - Returns: A decimated array of coordinates.
  static func simplifyPath(_ points: [CLLocationCoordinate2D], epsilon: Double) -> [CLLocationCoordinate2D] {
    guard points.count > 2 else { return points }
    
    var maxDistance = 0.0
    var index = 0
    
    let first = points.first!
    let last = points.last!
    
    for i in 1..<points.count - 1 {
      let distance = perpendicularDistance(from: points[i], lineStart: first, lineEnd: last)
      if distance > maxDistance {
        maxDistance = distance
        index = i
      }
    }
    
    if maxDistance > epsilon {
      let leftRecursive = simplifyPath(Array(points[0...index]), epsilon: epsilon)
      let rightRecursive = simplifyPath(Array(points[index...]), epsilon: epsilon)
      
      // Combine results, dropping the duplicate point at the index
      return leftRecursive.dropLast() + rightRecursive
    } else {
      return [first, last]
    }
  }
  
  /// Calculates the perpendicular distance of a point from a line segment.
  static func perpendicularDistance(from point: CLLocationCoordinate2D,
                                    lineStart a: CLLocationCoordinate2D,
                                    lineEnd b: CLLocationCoordinate2D) -> Double {
    let dx = b.longitude - a.longitude
    let dy = b.latitude - a.latitude
    let lengthSquared = dx * dx + dy * dy
    
    guard lengthSquared > 0 else {
      return sqrt(pow(point.longitude - a.longitude, 2) + pow(point.latitude - a.latitude, 2))
    }
    
    let t = max(0, min(1, ((point.longitude - a.longitude) * dx + (point.latitude - a.latitude) * dy) / lengthSquared))
    
    let projectionX = a.longitude + t * dx
    let projectionY = a.latitude + t * dy
    
    return sqrt(pow(projectionX - point.longitude, 2) + pow(projectionY - point.latitude, 2))
  }
  
  /// Calculates the geographic bearing between two coordinates in degrees.
  /// - Returns: Bearing in degrees (0...360).
  static func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
    let lat1 = start.latitude * .pi / 180
    let lon1 = start.longitude * .pi / 180
    let lat2 = end.latitude * .pi / 180
    let lon2 = end.longitude * .pi / 180
    
    let dLon = lon2 - lon1
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    
    let degrees = atan2(y, x) * 180 / .pi
    return (degrees + 360).truncatingRemainder(dividingBy: 360)
  }
  
  static func buildMarkers(_ pts: [CLLocationCoordinate2D], count: Int = 16) -> [OnLineMarker] {
    guard pts.count >= 2 else { return [] }
    let step = max(1, pts.count / (count + 1))
    var result: [OnLineMarker] = []
    var idx = step
    while idx < pts.count - 1 {
      let bearing = bearingBetween(pts[idx], pts[min(idx+1, pts.count-1)])
      result.append(OnLineMarker(id: idx, coordinate: pts[idx], bearing: bearing))
      idx += step
    }
    return result
  }
  
  static func bearingBetween(_ a: CLLocationCoordinate2D,
                      _ b: CLLocationCoordinate2D) -> Double {
    let lat1 = a.latitude  * .pi/180, lon1 = a.longitude * .pi/180
    let lat2 = b.latitude  * .pi/180, lon2 = b.longitude * .pi/180
    let dLon = lon2-lon1
    let y = sin(dLon)*cos(lat2)
    let x = cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon)
    return atan2(y, x) * 180 / .pi
  }
}
