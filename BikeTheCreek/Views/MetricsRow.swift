//
//  MetricsRow.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

struct MetricsRow: View {
  let session: RideSessionManager
  private var kmh:  String { String(format:"%.1f", session.currentSpeed*3.6) }
  private var km:   String { String(format:"%.2f", session.totalDistance/1000) }
  private var elev: String { String(format:"%.0f", session.currentElevation) }
  private var elapsed: String {
    let t = Int(session.elapsedTime)
    return String(format:"%d:%02d:%02d", t/3600,(t%3600)/60,t%60)
  }
  var body: some View {
    HStack(spacing:0) {
      MetCell(v:kmh,  u:"km/h", l:"SPEED")
      sep
      MetCell(v:km,   u:"km",   l:"DIST")
      sep
      MetCell(v:elapsed, u:"",  l:"TIME")
      sep
      MetCell(v:elev, u:"m",    l:"ELEV")
    }
    .padding(.vertical,10)
    .background(Color.glass).clipShape(.rect(cornerRadius:13))
    .overlay(RoundedRectangle(cornerRadius:13).strokeBorder(Color.white.opacity(0.06),lineWidth:1))
  }
  private var sep: some View {
    Rectangle().fill(Color.white.opacity(0.08)).frame(width:1,height:34)
  }
}
