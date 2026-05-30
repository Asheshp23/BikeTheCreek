//
//  Font+extension.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

extension Font {
  static func f(_ s: CGFloat, _ w: Font.Weight = .semibold) -> Font {
    .system(size: s, weight: w, design: .rounded)
  }
  static func mono(_ s: CGFloat, _ w: Font.Weight = .semibold) -> Font {
    .system(size: s, weight: w, design: .monospaced)
  }
}
