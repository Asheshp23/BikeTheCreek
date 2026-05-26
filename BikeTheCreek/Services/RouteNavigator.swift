import CoreLocation
import Foundation

struct RouteNavigator {
  private let route: BikeRoute
  private let segmentDistances: [CLLocationDistance]
  private let cumulativeDistances: [CLLocationDistance]
  
  init(route: BikeRoute) {
    self.route = route
    
    var segments: [CLLocationDistance] = []
    var cumulative: [CLLocationDistance] = [0]
    
    for (current, next) in zip(route.trackPoints, route.trackPoints.dropFirst()) {
      let distance = current.location.distance(from: next.location)
      segments.append(distance)
      cumulative.append((cumulative.last ?? 0) + distance)
    }
    
    self.segmentDistances = segments
    self.cumulativeDistances = cumulative
  }
  
  func cue(for location: CLLocation) -> NavigationCue? {
    guard route.trackPoints.count > 2,
          let nearest = nearestRouteIndex(to: location) else {
      return nil
    }
    
    let nearestCoordinate = route.trackPoints[nearest]
    let offRouteDistance = location.distance(from: nearestCoordinate.location)
    let totalDistance = cumulativeDistances.last ?? route.distanceMeters
    
    guard offRouteDistance < 75 else {
      return NavigationCue(
        direction: .offRoute,
        title: "Return to the highlighted route",
        distanceMeters: offRouteDistance,
        progress: progress(at: nearest, totalDistance: totalDistance)
      )
    }
    
    let remaining = max(totalDistance - cumulativeDistances[safe: nearest, default: totalDistance], 0)
    if remaining < 45 || nearest >= route.trackPoints.count - 2 {
      return NavigationCue(
        direction: .finish,
        title: "Finish ahead",
        distanceMeters: remaining,
        progress: 1
      )
    }
    
    let lookAhead = turnLookAheadIndex(from: nearest, targetDistance: 95)
    let direction = direction(from: nearest, through: lookAhead)
    let title = title(for: direction)
    let cueDistance = max(cumulativeDistances[safe: lookAhead, default: totalDistance] - cumulativeDistances[nearest], 0)
    
    return NavigationCue(
      direction: direction,
      title: title,
      distanceMeters: cueDistance,
      progress: progress(at: nearest, totalDistance: totalDistance)
    )
  }
  
  private func nearestRouteIndex(to location: CLLocation) -> Int? {
    route.trackPoints.indices.min { lhs, rhs in
      location.distance(from: route.trackPoints[lhs].location) < location.distance(from: route.trackPoints[rhs].location)
    }
  }
  
  private func turnLookAheadIndex(from index: Int, targetDistance: CLLocationDistance) -> Int {
    var distance: CLLocationDistance = 0
    var cursor = index
    
    while cursor < segmentDistances.count && distance < targetDistance {
      distance += segmentDistances[cursor]
      cursor += 1
    }
    
    return min(cursor, route.trackPoints.count - 1)
  }
  
  private func direction(from index: Int, through lookAhead: Int) -> NavigationCue.Direction {
    let previousIndex = max(index - 2, 0)
    let nextIndex = min(max(lookAhead, index + 2), route.trackPoints.count - 1)
    
    guard previousIndex != index, index != nextIndex else {
      return index < 3 ? .start : .continueStraight
    }
    
    let incoming = bearing(from: route.trackPoints[previousIndex], to: route.trackPoints[index])
    let outgoing = bearing(from: route.trackPoints[index], to: route.trackPoints[nextIndex])
    let delta = normalizedDegrees(outgoing - incoming)
    let magnitude = abs(delta)
    
    if magnitude < 18 {
      return index < 3 ? .start : .continueStraight
    } else if delta < 0 {
      if magnitude > 115 { return .sharpLeft }
      if magnitude > 45 { return .left }
      return .slightLeft
    } else {
      if magnitude > 115 { return .sharpRight }
      if magnitude > 45 { return .right }
      return .slightRight
    }
  }
  
  private func title(for direction: NavigationCue.Direction) -> String {
    switch direction {
    case .start: "Start riding the highlighted route"
    case .continueStraight: "Continue on route"
    case .slightLeft: "Bear left"
    case .left: "Turn left"
    case .sharpLeft: "Sharp left"
    case .slightRight: "Bear right"
    case .right: "Turn right"
    case .sharpRight: "Sharp right"
    case .offRoute: "Return to route"
    case .finish: "Finish ahead"
    }
  }
  
  private func progress(at index: Int, totalDistance: CLLocationDistance) -> Double {
    guard totalDistance > 0 else { return 0 }
    return min(max(cumulativeDistances[safe: index, default: 0] / totalDistance, 0), 1)
  }
  
  private func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationDirection {
    let startLat = start.latitude * .pi / 180
    let startLon = start.longitude * .pi / 180
    let endLat = end.latitude * .pi / 180
    let endLon = end.longitude * .pi / 180
    let deltaLon = endLon - startLon
    
    let y = sin(deltaLon) * cos(endLat)
    let x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(deltaLon)
    return atan2(y, x) * 180 / .pi
  }
  
  private func normalizedDegrees(_ degrees: CLLocationDirection) -> CLLocationDirection {
    var value = degrees.truncatingRemainder(dividingBy: 360)
    if value > 180 { value -= 360 }
    if value < -180 { value += 360 }
    return value
  }
}

private extension Array {
  subscript(safe index: Index, default defaultValue: Element) -> Element {
    indices.contains(index) ? self[index] : defaultValue
  }
}
