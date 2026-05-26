import Foundation
import SwiftUI
import MapKit

// MARK: - WaypointType UI helpers
extension WaypointType {
 
}

// MARK: - BikeRoute helpers used by UI
extension BikeRoute {
    // Rough bounding rect for the polyline
   
    private var totalDistanceMeters: Double {
        guard trackPoints.count > 1 else { return 0 }
        var total: Double = 0
        for i in 0..<(trackPoints.count - 1) {
            let a = CLLocation(latitude: trackPoints[i].latitude, longitude: trackPoints[i].longitude)
            let b = CLLocation(latitude: trackPoints[i+1].latitude, longitude: trackPoints[i+1].longitude)
            total += a.distance(from: b)
        }
        return total
    }
    
    private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let brng = atan2(y, x) * 180 / .pi
        return fmod(brng + 360, 360)
    }
}

struct RouteArrow: Identifiable, Hashable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let bearing: CLLocationDirection
}

// MARK: - UUID helpers used to style routes in UI
extension UUID {
    // Deterministic accent color per UUID
    var accentColor: Color {
        let hash = self.uuidString.hashValue
        let hue = Double(abs(hash % 360)) / 360.0
        return Color(hue: hue, saturation: 0.85, brightness: 0.9)
    }
    
    var shortName: String {
        let s = uuidString.prefix(4)
        return "Route \(s)"
    }
    
    var distanceLabel: String {
        return "—"
    }
    
    var durationLabel: String {
        return "—"
    }
    
    var routeCardAccessibilityID: String {
        return "route-card-\(uuidString)"
    }
}

// MARK: - Minimal NavigationCue used by UI
enum NavigationDirection {
    case left, right, straight, offRoute
}
