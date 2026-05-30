//
//  StartStopNode 2.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

struct StartStopNode: View {
  let routeColor: Color; var isFinish: Bool = false
  var body: some View {
    TerminusPin(label: isFinish ? "F" : "S",
                color: isFinish ? .creekDeep : .green,
                isFinish: isFinish)
  }
}
