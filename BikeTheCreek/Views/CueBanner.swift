//
//  CueBanner.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

struct CueBanner: View {
  let cue: NavigationCue
  private var accent: Color { cue.direction == .offRoute ? .red : .creek }
  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius:10).fill(accent).frame(width:42,height:42)
        Image(systemName: cue.systemImage)
          .font(.system(size:17, weight:.black)).foregroundStyle(.white)
      }
      VStack(alignment:.leading, spacing:2) {
        Text(cue.title.uppercased()).font(.f(12,.black)).foregroundStyle(.white).tracking(0.5)
        Text(cue.distanceLabel).font(.mono(11)).foregroundStyle(accent)
      }
      Spacer()
      ZStack {
        Circle().stroke(Color.white.opacity(0.1), lineWidth:3)
        Circle().trim(from:0, to:max(0,min(1,cue.progress)))
          .stroke(accent, style:StrokeStyle(lineWidth:3,lineCap:.round))
          .rotationEffect(.degrees(-90))
        Text("\(Int(cue.progress*100))%").font(.mono(8,.bold)).foregroundStyle(.white)
      }
      .frame(width:38, height:38)
    }
    .padding(.horizontal,14).padding(.vertical,10)
    .background(Color.glass).clipShape(.rect(cornerRadius:14))
    .overlay(RoundedRectangle(cornerRadius:14).strokeBorder(Color.white.opacity(0.07),lineWidth:1))
    .shadow(color:.black.opacity(0.35),radius:10,y:3)
    .accessibilityIdentifier("navigation-cue-banner")
  }
}
