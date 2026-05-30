//
//  TerminusPin.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

struct TerminusPin: View {
  let label: String; let color: Color; var isFinish = false
  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        Circle().fill(color).frame(width: 32, height: 32)
        if isFinish {
          Image(systemName: "flag.checkered")
            .font(.system(size:14, weight:.black)).foregroundStyle(.white)
        } else {
          Text(label)
            .font(.system(size:14, weight:.black, design:.rounded)).foregroundStyle(.white)
        }
      }
      .shadow(color: color.opacity(0.55), radius: 6, y: 2)
      Tri().fill(color).frame(width:9, height:7)
    }
  }
}
