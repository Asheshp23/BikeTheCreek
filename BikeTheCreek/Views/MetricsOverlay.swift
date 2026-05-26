//
//  MetricsOverlay.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-25.
//
import SwiftUI

struct MetricsOverlay: View {
    @ObservedObject var session: RideSessionManager

    var body: some View {
        HStack(spacing: 18) {
            MetricView(label: "SPEED", value: String(format: "%.1f", session.currentSpeed * 3.6), unit: "km/h")
            MetricView(label: "DIST", value: String(format: "%.2f", session.totalDistance / 1000), unit: "km")
            MetricView(label: "TIME", value: formatTime(session.elapsedTime), unit: "")
            MetricView(label: "ELEV", value: String(format: "%.0f", session.currentElevation), unit: "m")
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
    }
    
    func formatTime(_ totalSeconds: TimeInterval) -> String {
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) / 60 % 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
}

struct MetricView: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack {
            Text(label).font(.caption2).bold().foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 19, weight: .black, design: .rounded))
                Text(unit).font(.caption).bold()
            }
        }
        .frame(maxWidth: .infinity)
    }
}
