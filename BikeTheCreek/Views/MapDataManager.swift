import Foundation
import Combine

@MainActor
class MapDataManager: ObservableObject {
  @Published private(set) var routes: [BikeRoute] = []
  @Published var selectedRoute: BikeRoute?
  @Published var globalPavilions: [BikeWaypoint] = []
  @Published var cervPositions: [BikeWaypoint] = []
  
  init() {
    loadRoutes()
    loadGlobalData()
    selectedRoute = routes.first
  }
  
  var allVisibleWaypoints: [BikeWaypoint] {
    let pois = selectedRoute?.waypoints.filter { $0.type != .start && $0.type != .finish } ?? []
    return pois + globalPavilions + cervPositions
  }
  
  func selectRide(_ ride: RideType) {
    selectedRoute = routes.first { $0.id == ride }
  }
  
  private func loadRoutes() {
    routes = RideType.allCases.compactMap { GPXLoader.loadRide($0) }
  }
  
  private func loadGlobalData() {
    if let pavilionRoute = GPXLoader.loadGPXFile(named: "Pavillions") {
      self.globalPavilions = pavilionRoute.waypoints
    }
    
    if let cervRoute = GPXLoader.loadGPXFile(named: "CERV Positions") {
      self.cervPositions = cervRoute.waypoints.map {
        BikeWaypoint(name: $0.name, coordinate: $0.coordinate, type: .firstAid)
      }
    }
  }
}

