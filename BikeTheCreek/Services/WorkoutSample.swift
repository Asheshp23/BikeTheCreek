//
//  WorkoutDataManager.swift
//  BikeTheCreek
//
//  Unified workout data layer.
//  Sources: HealthKit (Apple Watch / iPhone) and GPX/FIT file import.
//  All data normalised into WorkoutSample for use across all visualisation views.
//

import CoreLocation
import Foundation
internal import HealthKit
import UIKit

// MARK: - Models

struct WorkoutSample: Identifiable {
  let id          = UUID()
  let coordinate  : CLLocationCoordinate2D
  let timestamp   : Date
  let heartRate   : Double?   // bpm
  let speed       : Double?   // m/s
  let altitude    : Double?   // metres
  let cadence     : Double?   // rpm
  let power       : Double?   // watts
}

enum HRZone: Int, CaseIterable {
  case zone1, zone2, zone3, zone4, zone5
  
  static func zone(for bpm: Double, max: Double = 190) -> HRZone {
    let pct = bpm / max
    switch pct {
    case ..<0.60: return .zone1
    case ..<0.70: return .zone2
    case ..<0.80: return .zone3
    case ..<0.90: return .zone4
    default:      return .zone5
    }
  }
  
  var color: UIColor {
    switch self {
    case .zone1: return UIColor(red: 0.20, green: 0.80, blue: 0.40, alpha: 1)
    case .zone2: return UIColor(red: 0.40, green: 0.80, blue: 0.20, alpha: 1)
    case .zone3: return UIColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1)
    case .zone4: return UIColor(red: 1.00, green: 0.45, blue: 0.00, alpha: 1)
    case .zone5: return UIColor(red: 0.90, green: 0.10, blue: 0.10, alpha: 1)
    }
  }
}

enum WorkoutMetric: String, CaseIterable, Identifiable {
  case heartRate = "Heart Rate"
  case speed     = "Speed"
  case altitude  = "Altitude"
  case cadence   = "Cadence"
  case power     = "Power"
  var id: String { rawValue }
  
  func value(from sample: WorkoutSample) -> Double? {
    switch self {
    case .heartRate: return sample.heartRate
    case .speed:     return sample.speed
    case .altitude:  return sample.altitude
    case .cadence:   return sample.cadence
    case .power:     return sample.power
    }
  }
  
  var unit: String {
    switch self {
    case .heartRate: return "bpm"
    case .speed:     return "km/h"
    case .altitude:  return "m"
    case .cadence:   return "rpm"
    case .power:     return "W"
    }
  }
}

// MARK: - Manager

@MainActor
@Observable
final class WorkoutDataManager {
  
  // MARK: Published state
  
  private(set) var workouts:        [HKWorkout]     = []
  private(set) var samples:         [WorkoutSample] = []
  private(set) var isLoading:       Bool            = false
  private(set) var error:           String?         = nil
  private(set) var importedSamples: [WorkoutSample] = []   // from GPX/FIT
  
  var allSamples: [WorkoutSample] { samples + importedSamples }
  
  // MARK: HealthKit
  
  private let store = HKHealthStore()
  
  private var readTypes: Set<HKObjectType> {
    let types: [HKQuantityTypeIdentifier] = [
      .heartRate, .distanceCycling, .activeEnergyBurned,
      .cyclingSpeed, .cyclingCadence, .cyclingPower,
      .distanceWalkingRunning
    ]
    var set: Set<HKObjectType> = Set(types.compactMap { HKQuantityType($0) })
    set.insert(HKSeriesType.workoutRoute())
    set.insert(HKObjectType.workoutType())
    return set
  }
  
  func requestHealthKitPermission() async {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    try? await store.requestAuthorization(toShare: [], read: readTypes)
  }
  
  func loadHealthKitWorkouts() async {
    isLoading = true; error = nil
    do {
      let pred = HKQuery.predicateForWorkouts(with: .cycling)
      let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
      let ws   = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKWorkout], Error>) in
        let q = HKSampleQuery(sampleType: .workoutType(),
                              predicate: pred,
                              limit: 50,
                              sortDescriptors: [sort]) { _, s, e in
          if let e { cont.resume(throwing: e) }
          else     { cont.resume(returning: s as? [HKWorkout] ?? []) }
        }
        store.execute(q)
      }
      workouts = ws
    } catch {
      self.error = error.localizedDescription
    }
    isLoading = false
  }
  
  func loadSamples(for workout: HKWorkout) async {
    isLoading = true; error = nil; samples = []
    do {
      let route      = try await fetchRoute(for: workout)
      let locations  = try await fetchLocations(for: route)
      let hrSamples  = try await fetchQuantity(.heartRate, for: workout)
      let spSamples  = try await fetchQuantity(.cyclingSpeed, for: workout)
      let cadSamples = try await fetchQuantity(.cyclingCadence, for: workout)
      let pwrSamples = try await fetchQuantity(.cyclingPower, for: workout)
      
      samples = locations.map { loc in
        WorkoutSample(
          coordinate: loc.coordinate,
          timestamp:  loc.timestamp,
          heartRate:  closestValue(hrSamples,  to: loc.timestamp, unit: HKUnit(from: "count/min")),
          speed:      closestValue(spSamples,  to: loc.timestamp, unit: .meter().unitDivided(by: .second())) .map { $0 * 3.6 },
          altitude:   loc.altitude,
          cadence:    closestValue(cadSamples, to: loc.timestamp, unit: HKUnit(from: "count/min")),
          power:      closestValue(pwrSamples, to: loc.timestamp, unit: .watt())
        )
      }
    } catch {
      self.error = error.localizedDescription
    }
    isLoading = false
  }
  
  // MARK: GPX / FIT import
  
  func importFile(url: URL) async {
    isLoading = true; error = nil
    do {
      _ = url.startAccessingSecurityScopedResource()
      defer { url.stopAccessingSecurityScopedResource() }
      let data = try Data(contentsOf: url)
      let ext  = url.pathExtension.lowercased()
      switch ext {
      case "gpx": importedSamples = try parseGPX(data)
      case "fit": importedSamples = try parseFIT(data)
      default:    self.error = "Unsupported file type: \(ext)"
      }
    } catch {
      self.error = error.localizedDescription
    }
    isLoading = false
  }
  
  // MARK: - Private HealthKit helpers
  
  private func fetchRoute(for workout: HKWorkout) async throws -> HKWorkoutRoute {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HKWorkoutRoute, Error>) in
      let pred = HKQuery.predicateForObjects(from: workout)
      let q = HKAnchoredObjectQuery(type: HKSeriesType.workoutRoute(),
                                    predicate: pred, anchor: nil, limit: 1) { _, s, _, _, e in
        if let e { cont.resume(throwing: e) }
        else if let r = s?.first as? HKWorkoutRoute { cont.resume(returning: r) }
        else { cont.resume(throwing: URLError(.fileDoesNotExist)) }
      }
      store.execute(q)
    }
  }
  
  private func fetchLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
    var all: [CLLocation] = []
    return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[CLLocation], Error>) in
      let q = HKWorkoutRouteQuery(route: route) { _, locs, done, e in
        if let e { cont.resume(throwing: e); return }
        all += locs ?? []
        if done { cont.resume(returning: all) }
      }
      store.execute(q)
    }
  }
  
  private func fetchQuantity(_ id: HKQuantityTypeIdentifier,
                             for workout: HKWorkout) async throws -> [HKQuantitySample] {
    guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [] }
    let pred = HKQuery.predicateForSamples(withStart: workout.startDate,
                                           end: workout.endDate)
    return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKQuantitySample], Error>) in
      let q = HKSampleQuery(sampleType: type, predicate: pred,
                            limit: HKObjectQueryNoLimit,
                            sortDescriptors: nil) { _, s, e in
        if let e { cont.resume(throwing: e) }
        else     { cont.resume(returning: s as? [HKQuantitySample] ?? []) }
      }
      store.execute(q)
    }
  }
  
  private func closestValue(_ samples: [HKQuantitySample],
                            to date: Date,
                            unit: HKUnit) -> Double? {
    samples.min(by: {
      abs($0.startDate.timeIntervalSince(date)) < abs($1.startDate.timeIntervalSince(date))
    })?.quantity.doubleValue(for: unit)
  }
  
  // MARK: - GPX parser (minimal)
  
  private func parseGPX(_ data: Data) throws -> [WorkoutSample] {
    let delegate = GPXParser()
    let parser   = XMLParser(data: data)
    parser.delegate = delegate
    guard parser.parse() else {
      throw parser.parserError ?? URLError(.cannotParseResponse)
    }
    return delegate.samples
  }
  
  // MARK: - FIT parser (binary — field definitions only, no external SDK)
  
  private func parseFIT(_ data: Data) throws -> [WorkoutSample] {
    // FIT files have a 12-byte global header; records follow.
    // This minimal parser extracts record messages (mesg_num=20)
    // for lat/lon/altitude/heart_rate/cadence/speed/power.
    // Full FIT SDK support can be swapped in by replacing this method.
    guard data.count > 12 else { throw URLError(.badServerResponse) }
    var samples: [WorkoutSample] = []
    var i = 12  // skip global header
    
    // Field numbers for record message (mesg_num 20)
    let fieldLat = 0, fieldLon = 1, fieldAlt = 2,
        fieldHR = 3, fieldCad = 4, fieldSpeed = 6, fieldPower = 7,
        fieldTimestamp = 253
    
    var defMsgFields: [Int: (num: Int, size: Int)] = [:]
    var localMsgDefs: [Int: [(num: Int, size: Int, base: Int)]] = [:]
    
    let fitEpoch = 631065600.0  // Jan 1 1989 in Unix time
    
    while i < data.count - 1 {
      let header = data[i]; i += 1
      let isDefn  = (header & 0x40) != 0
      let localNum = Int(header & 0x0F)
      
      if isDefn {
        i += 2  // reserved + arch
        let mesgNum = Int(data[i]) | (Int(data[i+1]) << 8); i += 2
        let numFields = Int(data[i]); i += 1
        var fields: [(num: Int, size: Int, base: Int)] = []
        for _ in 0..<numFields {
          let fn = Int(data[i]); let sz = Int(data[i+1]); let bt = Int(data[i+2])
          fields.append((fn, sz, bt)); i += 3
        }
        if mesgNum == 20 { localMsgDefs[localNum] = fields }
        else { for f in fields { i += 0; _ = f } }   // skip unknown
        _ = defMsgFields   // suppress warning
      } else {
        guard let fields = localMsgDefs[localNum] else {
          // unknown local msg — skip (we don't know size so bail)
          break
        }
        var vals: [Int: Double] = [:]
        for f in fields {
          var raw: Int64 = 0
          for b in 0..<f.size {
            raw |= Int64(data[i]) << (b * 8); i += 1
          }
          vals[f.num] = Double(raw)
        }
        guard let rawLat = vals[fieldLat], let rawLon = vals[fieldLon],
              rawLat != 2147483647, rawLon != 2147483647 else { continue }
        let lat  = rawLat  * (180.0 / 2_147_483_648.0)
        let lon  = rawLon  * (180.0 / 2_147_483_648.0)
        let alt  = vals[fieldAlt].map  { $0 / 5.0 - 500 }
        let hr   = vals[fieldHR]
        let cad  = vals[fieldCad]
        let spd  = vals[fieldSpeed].map { $0 / 1000.0 * 3.6 }
        let pwr  = vals[fieldPower]
        let ts   = vals[fieldTimestamp].map { Date(timeIntervalSince1970: $0 + fitEpoch) } ?? Date()
        samples.append(WorkoutSample(
          coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
          timestamp: ts, heartRate: hr, speed: spd,
          altitude: alt, cadence: cad, power: pwr))
      }
    }
    return samples
  }
}

// MARK: - GPXParser (SAX - iOS-compatible)

private final class GPXParser: NSObject, XMLParserDelegate {
  
  private(set) var samples: [WorkoutSample] = []
  
  private var inTrkpt     = false
  private var currentLat  : Double?
  private var currentLon  : Double?
  private var currentAlt  : Double?
  private var currentHR   : Double?
  private var currentCad  : Double?
  private var currentDate : Date?
  private var currentText  = ""
  
  private let iso = ISO8601DateFormatter()
  
  func parser(_ parser: XMLParser,
              didStartElement element: String,
              namespaceURI: String?,
              qualifiedName: String?,
              attributes: [String: String]) {
    currentText = ""
    if element == "trkpt" {
      inTrkpt    = true
      currentLat = attributes["lat"].flatMap(Double.init)
      currentLon = attributes["lon"].flatMap(Double.init)
      currentAlt = nil; currentHR = nil
      currentCad = nil; currentDate = nil
    }
  }
  
  func parser(_ parser: XMLParser, foundCharacters string: String) {
    currentText += string
  }
  
  func parser(_ parser: XMLParser,
              didEndElement element: String,
              namespaceURI: String?,
              qualifiedName: String?) {
    let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
    currentText = ""
    guard inTrkpt else { return }
    switch element {
    case "ele":  currentAlt  = Double(text)
    case "time": currentDate = iso.date(from: text)
    case "hr":   currentHR   = Double(text)
    case "cad":  currentCad  = Double(text)
    case "trkpt":
      guard let lat = currentLat, let lon = currentLon else { return }
      samples.append(WorkoutSample(
        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
        timestamp:  currentDate ?? Date(),
        heartRate:  currentHR,
        speed:      nil,
        altitude:   currentAlt,
        cadence:    currentCad,
        power:      nil))
      inTrkpt = false
    default: break
    }
  }
}

