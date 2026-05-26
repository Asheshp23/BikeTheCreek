import Foundation
import CoreLocation
import CoreGPX

struct GPXLoader {
  struct GPXPayload {
    let name: String
    let trackPoints: [CLLocationCoordinate2D]
    let waypoints: [BikeWaypoint]
  }
  
  static func loadRide(_ ride: RideType) -> BikeRoute? {
    let pathData = loadGPXFile(named: ride.lineStringFile)
    let pointData = loadGPXFile(named: ride.pointFile)
    let points = pathData?.trackPoints ?? []
    
    guard !points.isEmpty else { return nil }
    
    return BikeRoute(
      id: ride,
      name: ride.rawValue,
      trackPoints: points,
      waypoints: pointData?.waypoints ?? []
    )
  }
  
  static func loadGPXFile(named fileName: String) -> GPXPayload? {
    guard let url = url(forGPXNamed: fileName) else {
#if DEBUG
      print("[GPXLoader] Could not find GPX file named: \(fileName).gpx")
#endif
      return nil
    }
    
    let parser = GPXParser(withURL: url)
    let gpxOptional = parser?.parsedData()
    guard let gpx = gpxOptional else {
#if DEBUG
      print("[GPXLoader] Failed to parse GPX file at URL: \(url)")
#endif
      return nil
    }
    
    let coords: [CLLocationCoordinate2D] = gpx.tracks.flatMap { track in
      track.segments.flatMap { segment in
        segment.points.compactMap { tp in
          guard let lat = tp.latitude, let lon = tp.longitude else { return nil }
          return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
      }
    }
    
    let waypoints: [BikeWaypoint] = gpx.waypoints.enumerated().compactMap { index, wpt in
      guard let lat = wpt.latitude, let lon = wpt.longitude else { return nil }
      let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
      let name = wpt.name ?? "Point of Interest"
      
      let lower = name.lowercased()
      let type: WaypointType
      if lower.contains("start") {
        type = .start
      } else if lower.contains("end") || lower.contains("finish") {
        type = .finish
      } else if lower.contains("pavilion") || lower.contains("pavillion") {
        type = .pavilion
      } else if lower.contains("water") || lower.contains("hydration") {
        type = .water
      } else if lower.contains("first aid") || lower.contains("medical") || lower.contains("cerv") {
        type = .firstAid
      } else if lower.contains("point of interest") {
        type = .general
      } else {
        type = .junction
      }
      
      return BikeWaypoint(
        id: "\(fileName)-\(index)-\(lat)-\(lon)",
        name: name,
        coordinate: coordinate,
        type: type
      )
    }
    
    let gpxName = gpx.tracks.first?.name ?? fileName
    return GPXPayload(name: gpxName, trackPoints: coords, waypoints: waypoints)
  }
  
  private static func url(forGPXNamed fileName: String) -> URL? {
    if let rootURL = Bundle.main.url(forResource: fileName, withExtension: "gpx") {
      return rootURL
    }
    
    guard let resourceURL = Bundle.main.resourceURL,
          let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: nil
          ) else {
      return nil
    }
    
    for case let url as URL in enumerator where url.pathExtension == "gpx" {
      if url.deletingPathExtension().lastPathComponent == fileName {
        return url
      }
    }
    
    return nil
  }
}
