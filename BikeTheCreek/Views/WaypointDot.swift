//
//  WaypointDot.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

 struct WaypointDot: View {
  let waypoint: BikeWaypoint
  var body: some View {
    ZStack {
      Circle().fill(waypoint.type.color).frame(width:24,height:24)
      Image(systemName: waypoint.type.systemImage)
        .font(.system(size:10, weight:.bold)).foregroundStyle(.white)
    }
    .shadow(color:.black.opacity(0.28), radius:3, y:1)
    .accessibilityLabel(waypoint.name)
  }
}
