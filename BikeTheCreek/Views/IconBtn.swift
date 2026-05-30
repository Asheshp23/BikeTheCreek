//
//  IconBtn.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

struct IconBtn: View {
  let icon: String; let tint: Color; let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size:14, weight:.semibold)).foregroundStyle(tint)
        .frame(width:34, height:34)
        .background(Color.glass.background(.ultraThinMaterial))
        .clipShape(Circle())
        .shadow(color:.black.opacity(0.2),radius:6,y:2)
    }
  }
}
