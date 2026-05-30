//
//  Tri.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

 struct Tri: Shape {
  func path(in r: CGRect) -> Path {
    Path { p in
      p.move(to:.init(x:r.midX,y:r.maxY))
      p.addLine(to:.init(x:r.minX,y:r.minY))
      p.addLine(to:.init(x:r.maxX,y:r.minY))
      p.closeSubpath()
    }
  }
}
