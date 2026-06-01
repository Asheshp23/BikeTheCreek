//
//  RideNavigatorView.swift
//  BikeTheCreek
//
//  Pure view — zero business logic, zero direct manager access.
//  All state and actions live in RideNavigatorViewModel.
//

import MapKit
import SwiftUI

struct RideNavigatorView: View {
  
  @State private var vm = RideNavigatorViewModel()
  
  var body: some View {
    @Bindable var vm = vm  // enables $vm.cameraPosition etc.
    ZStack {
      mapView.ignoresSafeArea()
      topBar
      if vm.sessionActive  { activeHUD }
      if !vm.sessionActive { routeCardLayer }
    }
    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: vm.sessionActive)
    .animation(.spring(response: 0.30, dampingFraction: 0.80), value: vm.routerOpen)
    .onAppear { vm.onAppear() }
    .onChange(of: vm.dataManager.selectedRoute) { _, r in vm.onRouteChanged(r) }
    .accessibilityIdentifier("bike-the-creek-root")
  }
  
  // MARK: - Map
  
  private var mapView: some View {
    Map(position: $vm.cameraPosition,
        interactionModes: [.pan, .zoom, .rotate, .pitch]) {
      
      // ── Route overlay ──────────────────────────────────────────
      if !vm.smoothPts.isEmpty, let route = vm.dataManager.selectedRoute {
        GradientPolyline(pts: vm.smoothPts)
        
        ForEach(vm.markers) { m in
          Annotation("", coordinate: m.coordinate, anchor: .center) {
            DirectionChevron(bearing: m.bearing, mapHeading: vm.cameraHeading)
          }
        }
        
        if let s = route.trackPoints.first {
          Annotation("", coordinate: s, anchor: .bottom) {
            TerminusPin(label: "S", color: .green)
          }
        }
        if let e = route.trackPoints.last {
          Annotation("", coordinate: e, anchor: .bottom) {
            TerminusPin(label: "F", color: .creekDeep, isFinish: true)
          }
        }
      }
      
      // ── Recorded breadcrumb trail ──────────────────────────────
      if !vm.session.userPath.isEmpty {
        MapPolyline(coordinates: vm.session.userPath)
          .stroke(Color.white.opacity(0.70),
                  style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 4]))
      }
      
      // ── Waypoints ─────────────────────────────────────────────
      ForEach(vm.dataManager.allVisibleWaypoints) { wp in
        Annotation(wp.name, coordinate: wp.coordinate, anchor: .bottom) {
          WaypointDot(waypoint: wp)
        }
      }
      
      // ── Live user arrow (heading-corrected) ───────────────────
      Annotation("", coordinate: vm.userCoordinate, anchor: .center) {
        ZStack {
          Circle()
            .fill(.white)
            .frame(width: 36, height: 36)
          Image(systemName: "location.north.circle")
            .resizable()
            .foregroundStyle(.blue)
            .frame(width: 36, height: 36)
            .rotationEffect(.degrees(vm.arrowRotation))
        }
      }
    }
        .mapStyle(.standard(elevation: .realistic,
                            emphasis: .muted,
                            pointsOfInterest: .excludingAll))
        .mapControls { MapCompass(); MapScaleView(); MapPitchToggle() }
        .onMapCameraChange(frequency: .continuous) { context in
          vm.onCameraChange(context)
        }
  }
  
  // MARK: - Top bar
  
  private var topBar: some View {
    VStack {
      HStack {
        appLabel
          .padding(.leading, 16)
          .padding(.top, 8)
        Spacer()
        IconBtn(icon: "scope", tint: .creek) { vm.fitRoute() }
          .padding(.trailing, 16)
          .padding(.top, 8)
      }
      Spacer()
    }
  }
  
  private var appLabel: some View {
    Text("BIKE THE CREEK")
      .font(.f(11, .black))
      .foregroundStyle(.white)
      .tracking(1.8)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(Color.glass.background(.ultraThinMaterial).clipShape(Capsule()))
      .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
  }
  
  // MARK: - Active HUD (recording / previewing)
  
  private var activeHUD: some View {
    VStack(spacing: 8) {
      Spacer().frame(height: 80)
      if let cue = vm.session.navigationCue { CueBanner(cue: cue) }
      MetricsRow(session: vm.session)
      StopBtn(session: vm.session)
      Spacer()
    }
    .padding(.horizontal, 14)
    .transition(.opacity.combined(with: .move(edge: .top)))
  }
  
  // MARK: - Floating route card layer
  
  private var routeCardLayer: some View {
    VStack {
      Spacer()
      HStack(alignment: .bottom) {
        routeFloater
          .padding(.leading, 16)
          .padding(.bottom, 32)
        Spacer()
      }
    }
    .transition(.opacity.combined(with: .move(edge: .bottom)))
  }
  
  // MARK: - Route floater (card + optional switcher above)
  
  @ViewBuilder
  private var routeFloater: some View {
    VStack(alignment: .leading, spacing: 8) {
      if vm.routerOpen {
        routeSwitcher
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      compactCard
    }
  }
  
  // MARK: - Compact card
  
  private var compactCard: some View {
    HStack(spacing: 0) {
      if let route = vm.dataManager.selectedRoute {
        
        // Colour swatch + distance
        ZStack {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(
              colors: [.green, .creek, .creekDeep],
              startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 48, height: 48)
          VStack(spacing: 0) {
            Text(route.id.distanceLabel.replacingOccurrences(of: " km", with: ""))
              .font(.f(15, .black)).foregroundStyle(.white)
            Text("KM")
              .font(.f(7, .bold)).foregroundStyle(.white.opacity(0.7)).tracking(1)
          }
        }
        .padding(.trailing, 10)
        
        // Route info
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(route.id.shortName.uppercased())
              .font(.f(13, .black)).foregroundStyle(.white).tracking(0.2)
            statusChip
          }
          Label(route.id.durationLabel, systemImage: "clock")
            .font(.mono(9)).foregroundStyle(Color.white.opacity(0.42))
        }
        
        Spacer(minLength: 10)
        
        // Route-list toggle
        Button { vm.toggleRouter() } label: {
          Image(systemName: vm.routerOpen ? "xmark" : "list.bullet")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.creek)
            .frame(width: 32, height: 32)
            .background(Color.creek.opacity(0.12))
            .clipShape(Circle())
        }
        .padding(.leading, 8)
        
        // Preview button
        Button { vm.startPreview() } label: {
          HStack(spacing: 4) {
            Image(systemName: "play.fill").font(.system(size: 11, weight: .black))
            Text("Preview").font(.f(12, .black)).tracking(0.8)
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 14)
          .frame(height: 36)
          .background(
            LinearGradient(colors: [.creek, .creekDeep],
                           startPoint: .leading, endPoint: .trailing))
          .clipShape(Capsule())
        }
        .disabled(vm.session.isPreviewingRoute)
        .padding(.leading, 8)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      Color.surface
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.38), radius: 20, y: 6)
  }
  
  // MARK: - Route switcher
  
  private var routeSwitcher: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("CHOOSE ROUTE")
        .font(.f(9, .black))
        .foregroundStyle(Color.white.opacity(0.4))
        .tracking(1.4)
        .padding(.horizontal, 4)
      
      ForEach(vm.dataManager.routes) { route in
        routeRow(route)
      }
      
      Button { vm.toggleRecording() } label: {
        HStack(spacing: 7) {
          Image(systemName: vm.session.isRecording ? "stop.fill" : "record.circle")
            .font(.system(size: 13, weight: .black))
          Text(vm.session.isRecording ? "STOP RIDE" : "RECORD RIDE")
            .font(.f(13, .black)).tracking(0.6)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(
          vm.session.isRecording
          ? AnyView(Color.red)
          : AnyView(LinearGradient(colors: [.creek, .creekDeep],
                                   startPoint: .leading, endPoint: .trailing))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
      .buttonStyle(Bounce())
      .padding(.top, 4)
      .accessibilityIdentifier("start-stop-ride-button")
    }
    .padding(12)
    .background(
      Color.surface
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.3), radius: 16, y: 4)
    .frame(maxWidth: 280)
  }
  
  private func routeRow(_ route: BikeRoute) -> some View {
    let isSelected = route.id == vm.dataManager.selectedRoute?.id
    return Button { vm.selectRoute(route.id) } label: {
      HStack(spacing: 10) {
        Circle()
          .fill(vm.routeSegmentColor(route))
          .frame(width: 8, height: 8)
        Text(route.id.shortName)
          .font(.f(13, isSelected ? .black : .medium))
          .foregroundStyle(isSelected ? .white : Color.white.opacity(0.55))
        Spacer()
        Text(route.id.distanceLabel)
          .font(.mono(11, isSelected ? .bold : .regular))
          .foregroundStyle(isSelected ? Color.creek : Color.white.opacity(0.35))
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Color.creek)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 7)
      .background(isSelected ? Color.creek.opacity(0.10) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(Bounce())
    .accessibilityIdentifier(route.id.routeCardAccessibilityID)
  }
  
  // MARK: - Status chip
  
  private var statusChip: some View {
    let (t, c) = vm.statusChipContent
    return Text(t)
      .font(.f(8, .black)).foregroundStyle(c).tracking(1.1)
      .padding(.horizontal, 5).padding(.vertical, 2)
      .background(c.opacity(0.15)).clipShape(Capsule())
      .overlay(Capsule().strokeBorder(c.opacity(0.3), lineWidth: 0.5))
  }
}
