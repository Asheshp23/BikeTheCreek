//
//  DirectionChevron.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

struct DirectionChevron: View {
  let bearing: Double
  let mapHeading: Double   // current camera heading — subtract to cancel map rotation
  
  var body: some View {
    ZStack {
      Capsule()
        .fill(Color.black.opacity(0.55))
        .frame(width: 20, height: 14)
      Image(systemName: "chevron.forward")
        .font(.system(size: 9, weight: .black))
        .foregroundStyle(.white)
    }
    .rotationEffect(.degrees(bearing - mapHeading - 90))
  }
}
