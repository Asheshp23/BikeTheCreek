//
//  ContentView.swift
//  BikeTheCreek
//
//  Direction arrows: computed from decimated smoothPts — always on the line.
//  Modal rethink: floating bottom-left card (never sheets or slides).
//  Collapsed = compact pill. Expanded = route switcher floats above it.
//

import MapKit
import SwiftUI

// MARK: - Design tokens

private extension Color {
  static let creek     = Color(red: 0.153, green: 0.725, blue: 0.604)
  static let creekDeep = Color(red: 0.102, green: 0.502, blue: 0.420)
  static let surface   = Color(red: 0.09,  green: 0.09,  blue: 0.10)
  static let card      = Color(red: 0.15,  green: 0.15,  blue: 0.16)
  static let glass     = Color.black.opacity(0.70)
}

private extension Font {
  static func f(_ s: CGFloat, _ w: Font.Weight = .semibold) -> Font {
    .system(size: s, weight: w, design: .rounded)
  }
  static func mono(_ s: CGFloat, _ w: Font.Weight = .semibold) -> Font {
    .system(size: s, weight: w, design: .monospaced)
  }
}

// MARK: - On-line direction marker
// Bearing and coordinate both come from the same decimated array
// so the chevron is always centred on the visible polyline.

private struct OnLineMarker: Identifiable {
  let id: Int
  let coordinate: CLLocationCoordinate2D
  let bearing: Double
}

// MARK: - RDP decimation

private func rdp(_ pts: [CLLocationCoordinate2D], eps: Double) -> [CLLocationCoordinate2D] {
  guard pts.count > 2 else { return pts }
  var maxD = 0.0, maxI = 0
  let a = pts.first!, b = pts.last!
  for i in 1..<pts.count-1 {
    let d = perpDist(pts[i], a, b)
    if d > maxD { maxD = d; maxI = i }
  }
  if maxD > eps {
    return rdp(Array(pts[0...maxI]), eps: eps).dropLast() + rdp(Array(pts[maxI...]), eps: eps)
  }
  return [a, b]
}

private func perpDist(_ p: CLLocationCoordinate2D,
                      _ a: CLLocationCoordinate2D,
                      _ b: CLLocationCoordinate2D) -> Double {
  let dx = b.longitude-a.longitude, dy = b.latitude-a.latitude
  let l2 = dx*dx+dy*dy
  guard l2 > 0 else {
    return sqrt(pow(p.longitude-a.longitude,2)+pow(p.latitude-a.latitude,2))
  }
  let t = max(0, min(1, ((p.longitude-a.longitude)*dx+(p.latitude-a.latitude)*dy)/l2))
  return sqrt(pow(a.longitude+t*dx-p.longitude,2)+pow(a.latitude+t*dy-p.latitude,2))
}

private func bearingBetween(_ a: CLLocationCoordinate2D,
                            _ b: CLLocationCoordinate2D) -> Double {
  let lat1 = a.latitude  * .pi/180, lon1 = a.longitude * .pi/180
  let lat2 = b.latitude  * .pi/180, lon2 = b.longitude * .pi/180
  let dLon = lon2-lon1
  let y = sin(dLon)*cos(lat2)
  let x = cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon)
  return atan2(y, x) * 180 / .pi
}

// Build ~16 on-line markers directly from the decimated coordinate array.
// Both position and bearing are from the same array → arrows sit on the line.
private func buildMarkers(_ pts: [CLLocationCoordinate2D], count: Int = 16) -> [OnLineMarker] {
  guard pts.count >= 2 else { return [] }
  let step = max(1, pts.count / (count + 1))
  var result: [OnLineMarker] = []
  var idx = step
  while idx < pts.count - 1 {
    let bearing = bearingBetween(pts[idx], pts[min(idx+1, pts.count-1)])
    result.append(OnLineMarker(id: idx, coordinate: pts[idx], bearing: bearing))
    idx += step
  }
  return result
}

// MARK: - Route cache (smooth pts + on-line markers)

private actor RouteCache {
  static let shared = RouteCache()
  private var smooth:  [RideType: [CLLocationCoordinate2D]] = [:]
  private var markers: [RideType: [OnLineMarker]]           = [:]
  
  func resolve(_ r: BikeRoute) -> ([CLLocationCoordinate2D], [OnLineMarker]) {
    let pts: [CLLocationCoordinate2D]
    if let c = smooth[r.id] { pts = c }
    else { pts = rdp(r.trackPoints, eps: 0.00004); smooth[r.id] = pts }
    
    let mrk: [OnLineMarker]
    if let c = markers[r.id] { mrk = c }
    else { mrk = buildMarkers(pts); markers[r.id] = mrk }
    
    return (pts, mrk)
  }
}

// MARK: - Gradient polyline (green → teal → deep teal)

private struct GradientPolyline: MapContent {
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

// MARK: - Direction chevron
// Pill background keeps the arrow readable on any map tile colour.
// Sized to sit visually ON the 5pt polyline width.

private struct DirectionChevron: View {
  let bearing: Double
  var body: some View {
    ZStack {
      Capsule()
        .fill(Color.black.opacity(0.55))
        .frame(width: 20, height: 14)
      Image(systemName: "chevron.forward")
        .font(.system(size: 9, weight: .black))
        .foregroundStyle(.white)
    }
    .rotationEffect(.degrees(bearing - 90))
  }
}

// MARK: - ContentView

struct ContentView: View {
  @StateObject private var dataManager = MapDataManager()
  @StateObject private var session     = RideSessionManager()
  
  @State private var position:   MapCameraPosition        = .userLocation(fallback: .automatic)
  @State private var smoothPts:  [CLLocationCoordinate2D] = []
  @State private var markers:    [OnLineMarker]           = []
  @State private var routerOpen = false   // route-switcher popover above card
  
  private var sessionActive: Bool { session.isPreviewingRoute || session.isRecording }
  
  var body: some View {
    ZStack {
      mapView.ignoresSafeArea()
      
      // Top-left app label
      VStack {
        HStack {
          appLabel
            .padding(.leading, 16)
            .padding(.top, 8)
          Spacer()
          IconBtn(icon: "scope", tint: .creek) { fitRoute() }
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        Spacer()
      }
      
      // Active HUD — recording or previewing
      if sessionActive {
        VStack(spacing: 8) {
          Spacer().frame(height: 80)
          if let cue = session.navigationCue { CueBanner(cue: cue) }
          MetricsRow(session: session)
          StopBtn(session: session)
          Spacer()
        }
        .padding(.horizontal, 14)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
      
      // Floating route card — bottom-left, always visible when not active
      if !sessionActive {
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
    }
    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: sessionActive)
    .animation(.spring(response: 0.30, dampingFraction: 0.80), value: routerOpen)
    .onAppear {
      session.prepareNavigation(for: dataManager.selectedRoute)
      fitRoute()
      refresh(dataManager.selectedRoute)
    }
    .onChange(of: dataManager.selectedRoute) { _, r in
      if session.isPreviewingRoute || session.routePreviewCompleted {
        session.stopRoutePreview(clearPath: true)
      }
      session.prepareNavigation(for: r)
      fitRoute()
      refresh(r)
      withAnimation { routerOpen = false }
    }
    .accessibilityIdentifier("bike-the-creek-root")
  }
  
  // MARK: - Map
  
  private var mapView: some View {
    Map(position: $position, interactionModes: [.pan, .zoom, .rotate, .pitch]) {
      if !smoothPts.isEmpty, let route = dataManager.selectedRoute {
        GradientPolyline(pts: smoothPts)
        
        // On-line chevrons — position & bearing from the same decimated array
        ForEach(markers) { m in
          Annotation("", coordinate: m.coordinate, anchor: .center) {
            DirectionChevron(bearing: m.bearing)
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
      
      if !session.userPath.isEmpty {
        MapPolyline(coordinates: session.userPath)
          .stroke(Color.white.opacity(0.70),
                  style: StrokeStyle(lineWidth:3, lineCap:.round, dash:[5,4]))
      }
      
      ForEach(dataManager.allVisibleWaypoints) { wp in
        Annotation(wp.name, coordinate: wp.coordinate, anchor: .bottom) {
          WaypointDot(waypoint: wp)
        }
      }
      
      UserAnnotation()
    }
    .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll))
    .mapControls { MapCompass(); MapScaleView(); MapPitchToggle() }
    .onMapCameraChange(frequency: .continuous) { _ in
      // Collapse route switcher when user starts panning
      if routerOpen { withAnimation { routerOpen = false } }
    }
  }
  
  // MARK: - App label (top-left pill)
  
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
  
  // MARK: - Floating route card
  
  @ViewBuilder
  private var routeFloater: some View {
    VStack(alignment: .leading, spacing: 8) {
      
      // ── Route switcher — slides up from card ─────────────────
      if routerOpen {
        routeSwitcher
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      
      // ── Compact card — always visible ────────────────────────
      compactCard
    }
  }
  
  private var compactCard: some View {
    HStack(spacing: 0) {
      // Colour swatch + distance
      if let route = dataManager.selectedRoute {
        ZStack {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(
              colors: [.green, .creek, .creekDeep],
              startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .frame(width: 48, height: 48)
          VStack(spacing: 0) {
            Text(route.id.distanceLabel.replacingOccurrences(of: " km", with: ""))
              .font(.f(15, .black)).foregroundStyle(.white)
            Text("KM").font(.f(7, .bold)).foregroundStyle(.white.opacity(0.7)).tracking(1)
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
          HStack(spacing: 6) {
            Label(route.id.durationLabel, systemImage: "clock")
          }
          .font(.mono(9)).foregroundStyle(Color.white.opacity(0.42))
        }
        
        Spacer(minLength: 10)
        
        // Route picker toggle
        Button {
          withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            routerOpen.toggle()
          }
        } label: {
          Image(systemName: routerOpen ? "xmark" : "list.bullet")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.creek)
            .frame(width: 32, height: 32)
            .background(Color.creek.opacity(0.12))
            .clipShape(Circle())
        }
        .padding(.leading, 8)
        
        // Go / record button
        Button {
          withAnimation { session.startRoutePreview(route: dataManager.selectedRoute) }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "play.fill").font(.system(size: 11, weight: .black))
            Text("GO").font(.f(12, .black)).tracking(0.8)
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 14)
          .frame(height: 36)
          .background(
            LinearGradient(colors: [.creek, .creekDeep], startPoint: .leading, endPoint: .trailing)
          )
          .clipShape(Capsule())
        }
        .disabled(session.isPreviewingRoute)
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
  
  // MARK: - Route switcher (pops above card)
  
  private var routeSwitcher: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("CHOOSE ROUTE")
        .font(.f(9, .black))
        .foregroundStyle(Color.white.opacity(0.4))
        .tracking(1.4)
        .padding(.horizontal, 4)
      
      ForEach(dataManager.routes) { route in
        routeRow(route)
      }
      
      // Record button
      Button {
        withAnimation {
          routerOpen = false
          session.toggleRecording(route: dataManager.selectedRoute)
        }
      } label: {
        HStack(spacing: 7) {
          Image(systemName: session.isRecording ? "stop.fill" : "record.circle")
            .font(.system(size: 13, weight: .black))
          Text(session.isRecording ? "STOP RIDE" : "RECORD RIDE")
            .font(.f(13, .black)).tracking(0.6)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(
          session.isRecording
          ? AnyView(Color.red)
          : AnyView(LinearGradient(colors:[.creek,.creekDeep], startPoint:.leading, endPoint:.trailing))
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
    let isSelected = route.id == dataManager.selectedRoute?.id
    return Button {
      withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
        dataManager.selectRide(route.id)
      }
    } label: {
      HStack(spacing: 10) {
        // Colour dot matching segment colours
        Circle()
          .fill(routeSegmentColor(route))
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
  
  // Each route gets a colour hint based on distance (short=green, long=deep)
  private func routeSegmentColor(_ route: BikeRoute) -> Color {
    switch route.id {
    case .leisure:  return .green
    case .family:   return Color(red:0.2,green:0.75,blue:0.55)
    case .bramalea: return Color.creek
    case .caledon:  return Color(red:0.12,green:0.58,blue:0.48)
    case .regional: return Color.creekDeep
    }
  }
  
  // MARK: - Status chip
  
  private var statusChip: some View {
    let (t,c): (String,Color) = {
      if session.isRecording           { return ("LIVE", .red)   }
      if session.routePreviewCompleted { return ("DONE", .green) }
      return ("READY", .creek)
    }()
    return Text(t)
      .font(.f(8, .black)).foregroundStyle(c).tracking(1.1)
      .padding(.horizontal, 5).padding(.vertical, 2)
      .background(c.opacity(0.15)).clipShape(Capsule())
      .overlay(Capsule().strokeBorder(c.opacity(0.3), lineWidth: 0.5))
  }
  
  // MARK: - Helpers
  
  private func fitRoute() {
    guard let r = dataManager.selectedRoute else { return }
    withAnimation(.easeInOut(duration: 0.8)) { position = .rect(r.mapRect) }
  }
  
  private func refresh(_ route: BikeRoute?) {
    smoothPts = []; markers = []
    guard let route else { return }
    Task.detached(priority: .userInitiated) {
      let (pts, mrk) = await RouteCache.shared.resolve(route)
      await MainActor.run { smoothPts = pts; markers = mrk }
    }
  }
}

// MARK: - Stop button

private struct StopBtn: View {
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

// MARK: - Map annotations

private struct TerminusPin: View {
  let label: String; let color: Color; var isFinish = false
  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        Circle().fill(color).frame(width: 32, height: 32)
        if isFinish {
          Image(systemName: "flag.checkered")
            .font(.system(size:14, weight:.black)).foregroundStyle(.white)
        } else {
          Text(label)
            .font(.system(size:14, weight:.black, design:.rounded)).foregroundStyle(.white)
        }
      }
      .shadow(color: color.opacity(0.55), radius: 6, y: 2)
      Tri().fill(color).frame(width:9, height:7)
    }
  }
}

private struct Tri: Shape {
  func path(in r: CGRect) -> Path {
    Path { p in
      p.move(to:.init(x:r.midX,y:r.maxY))
      p.addLine(to:.init(x:r.minX,y:r.minY))
      p.addLine(to:.init(x:r.maxX,y:r.minY))
      p.closeSubpath()
    }
  }
}

private struct WaypointDot: View {
  let waypoint: BikeWaypoint
  var body: some View {
    ZStack {
      Circle().fill(waypoint.type.color).frame(width:24,height:24)
      Image(systemName: waypoint.type.systemImage)
        .font(.system(size:10, weight:.bold)).foregroundStyle(.white)
    }
    .shadow(color:.black.opacity(0.28), radius:3, y:1)
    .accessibilityLabel(waypoint.name)
  }
}

// MARK: - Cue banner

private struct CueBanner: View {
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

// MARK: - Metrics bar

private struct MetricsRow: View {
  @ObservedObject var session: RideSessionManager
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

private struct MetCell: View {
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

// MARK: - Shared components

private struct IconBtn: View {
  let icon: String; let tint: Color; let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size:14, weight:.semibold)).foregroundStyle(tint)
        .frame(width:34, height:34)
        .background(Color.glass.background(.ultraThinMaterial))
        .clipShape(Circle())
        .shadow(color:.black.opacity(0.2),radius:6,y:2)
    }
  }
}

private struct Bounce: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .opacity(configuration.isPressed ? 0.86 : 1)
      .animation(.spring(response:0.2,dampingFraction:0.7), value:configuration.isPressed)
  }
}

// MARK: - Compat shim

struct StartStopNode: View {
  let routeColor: Color; var isFinish: Bool = false
  var body: some View {
    TerminusPin(label: isFinish ? "F" : "S",
                color: isFinish ? .creekDeep : .green,
                isFinish: isFinish)
  }
}

#Preview { ContentView() }
