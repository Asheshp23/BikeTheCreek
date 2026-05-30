//
//  Bounce.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

struct Bounce: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .opacity(configuration.isPressed ? 0.86 : 1)
      .animation(.spring(response:0.2,dampingFraction:0.7), value:configuration.isPressed)
  }
}
