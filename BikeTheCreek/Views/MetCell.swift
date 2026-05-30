//
//  MetCell.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

struct MetCell: View {
  let v: String; let u: String; let l: String
  var body: some View {
    VStack(spacing:2) {
      HStack(alignment:.lastTextBaseline, spacing:2) {
        Text(v).font(Font.mono(18,.black)).foregroundStyle(.white).monospacedDigit()
        if !u.isEmpty { Text(u).font(Font.mono(9)).foregroundStyle(Color.creek) }
      }
      Text(l).font(Font.f(8,.bold)).foregroundStyle(Color.white.opacity(0.34)).tracking(1.2)
    }
    .frame(maxWidth:.infinity)
  }
}
