//
//  StopBtn.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI

struct StopBtn: View {
  let session: RideSessionManager
  
  var body: some View {
    if session.isPreviewingRoute || session.isPreviewPaused || session.routePreviewCompleted {
      HStack(spacing: 10) {
        if !session.routePreviewCompleted {
          Button {
            withAnimation { session.toggleRoutePreviewPause() }
          } label: {
            Label(session.isPreviewPaused ? "Resume" : "Pause",
                  systemImage: session.isPreviewPaused ? "play.fill" : "pause.fill")
              .font(.f(14, .black))
              .tracking(0.4)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity, minHeight: 50)
              .background(Color.creek)
              .clipShape(.rect(cornerRadius: 12))
          }
          .buttonStyle(Bounce())
        }
        
        Button {
          withAnimation { session.stopRoutePreview(clearPath: true) }
        } label: {
          Label(session.routePreviewCompleted ? "Done" : "End Preview", systemImage: "stop.fill")
            .font(.f(14, .black))
            .tracking(0.4)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(session.routePreviewCompleted ? Color.green : Color.red)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(Bounce())
      }
      .padding(.top, 2)
    } else {
      Button {
        withAnimation { session.stopRecording() }
      } label: {
        Label("End Ride", systemImage: "stop.fill")
          .font(.f(14, .black))
          .tracking(0.4)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity, minHeight: 50)
          .background(Color.red)
          .clipShape(.rect(cornerRadius: 12))
      }
      .buttonStyle(Bounce())
      .padding(.top, 2)
    }
  }
}
