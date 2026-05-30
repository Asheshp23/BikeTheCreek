//
//  GradientPolyline.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-05-27.
//
import SwiftUI
import MapKit

struct GradientPolyline: MapContent {
  let pts: [CLLocationCoordinate2D]
  
  private var segs: ([CLLocationCoordinate2D],[CLLocationCoordinate2D],[CLLocationCoordinate2D]) {
    guard pts.count >= 3 else { return (pts,[],[]) }
    let n=pts.count, t1=n/3, t2=(n*2)/3
    return (Array(pts[0...t1]), Array(pts[t1...t2]), Array(pts[t2...]))
  }
  
  var body: some MapContent {
    let (s,m,e) = segs
    // Glow layers
    MapPolyline(coordinates: s)
      .stroke(Color.green.opacity(0.16), style: StrokeStyle(lineWidth:16,lineCap:.round,lineJoin:.round))
    if !m.isEmpty {
      MapPolyline(coordinates: m)
        .stroke(Color.creek.opacity(0.16), style: StrokeStyle(lineWidth:16,lineCap:.round,lineJoin:.round))
    }
    if !e.isEmpty {
      MapPolyline(coordinates: e)
        .stroke(Color.creekDeep.opacity(0.16), style: StrokeStyle(lineWidth:16,lineCap:.round,lineJoin:.round))
    }
    // Core lines
    MapPolyline(coordinates: s)
      .stroke(Color.green, style: StrokeStyle(lineWidth:5,lineCap:.round,lineJoin:.round))
    if !m.isEmpty {
      MapPolyline(coordinates: m)
        .stroke(Color.creek, style: StrokeStyle(lineWidth:5,lineCap:.round,lineJoin:.round))
    }
    if !e.isEmpty {
      MapPolyline(coordinates: e)
        .stroke(Color.creekDeep, style: StrokeStyle(lineWidth:5,lineCap:.round,lineJoin:.round))
    }
    // Shared specular
    MapPolyline(coordinates: pts)
      .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth:1.4,lineCap:.round,lineJoin:.round))
  }
}
