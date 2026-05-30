//
//  StopBtn.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

struct StopBtn: View {
  @ObservedObject var session: RideSessionManager
  var body: some View {
    Button {
      withAnimation {
        if session.isPreviewingRoute { session.stopRoutePreview(clearPath: true) }
        else { session.stopRecording() }
      }
    } label: {
      Label(session.isPreviewingRoute ? "Stop Preview" : "End Ride", systemImage: "stop.fill")
        .font(.f(14, .black)).tracking(0.4).foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(session.isPreviewingRoute ? Color.creek : Color.red)
        .clipShape(.rect(cornerRadius: 12))
    }
    .buttonStyle(Bounce()).padding(.top, 2)
  }
}
