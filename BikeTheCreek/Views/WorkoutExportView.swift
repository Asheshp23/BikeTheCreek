//
//  WorkoutExportView.swift
//  BikeTheCreek
//
//  Workout image compositor.
//  - CoreML foreground separation (Vision + VNGenerateForegroundInstanceMaskRequest)
//  - Route map snapshot rendered behind the foreground subject
//  - Metric stats block overlay
//  - Share sheet export
//

import CoreImage
import CoreImage.CIFilterBuiltins
import CoreLocation
import MapKit
import Photos
import SwiftUI
import Vision

// MARK: - View

struct WorkoutExportView: View {
  
  let samples: [WorkoutSample]
  @State private var vm: WorkoutExportViewModel
  
  init(samples: [WorkoutSample]) {
    self.samples = samples
    _vm = State(initialValue: WorkoutExportViewModel(samples: samples))
  }
  
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        canvasPreview
        photoPickerSection
        filterSection
        statsSection
        actionRow
      }
      .padding(16)
    }
    .navigationTitle("Export Image")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $vm.showShareSheet) {
      if let img = vm.composited {
        ShareSheet(items: [img])
      }
    }
    .alert("Saved!", isPresented: $vm.showSavedAlert) {
      Button("OK", role: .cancel) {}
    }
  }
  
  // MARK: - Canvas preview
  
  private var canvasPreview: some View {
    ZStack {
      if let img = vm.composited {
        Image(uiImage: img)
          .resizable()
          .scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      } else {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(Color.white.opacity(0.06))
          .frame(height: 320)
          .overlay {
            if vm.isProcessing {
              VStack(spacing: 10) {
                ProgressView().tint(.creek)
                Text(vm.processingStep)
                  .font(.system(size: 12, weight: .medium))
                  .foregroundStyle(Color.white.opacity(0.5))
              }
            } else {
              Text("Pick a photo to begin")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.3))
            }
          }
      }
    }
  }
  
  // MARK: - Photo picker
  
  private var photoPickerSection: some View {
    Button {
      vm.showPhotoPicker = true
    } label: {
      Label(vm.subjectImage == nil ? "Choose Photo" : "Change Photo",
            systemImage: "photo.on.rectangle")
      .font(.system(size: 14, weight: .bold))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 44)
      .background(Color.creek)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .sheet(isPresented: $vm.showPhotoPicker) {
      ImagePicker(image: $vm.subjectImage)
        .ignoresSafeArea()
    }
    .onChange(of: vm.subjectImage) { _, img in
      if img != nil { Task { await vm.compose() } }
    }
  }
  
  // MARK: - Filter strip
  
  private var filterSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("STYLE")
        .font(.f(9, .black)).foregroundStyle(Color.white.opacity(0.4)).tracking(1.4)
      
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(ExportFilter.allCases) { f in
            Button {
              vm.selectedFilter = f
              if vm.subjectImage != nil { Task { await vm.compose() } }
            } label: {
              VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .fill(f.previewGradient)
                  .frame(width: 56, height: 56)
                  .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                      .strokeBorder(
                        vm.selectedFilter == f ? Color.creek : Color.clear,
                        lineWidth: 2)
                  )
                Text(f.rawValue)
                  .font(.system(size: 9, weight: .bold))
                  .foregroundStyle(vm.selectedFilter == f ? .white : Color.white.opacity(0.4))
              }
            }
          }
        }
      }
    }
  }
  
  // MARK: - Stats section
  
  private var statsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("STATS OVERLAY")
        .font(.f(9, .black)).foregroundStyle(Color.white.opacity(0.4)).tracking(1.4)
      
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        ForEach(WorkoutMetric.allCases) { metric in
          metricToggleRow(metric)
        }
      }
    }
  }
  
  private func metricToggleRow(_ metric: WorkoutMetric) -> some View {
    let on = vm.visibleStats.contains(metric)
    return Button {
      if on { vm.visibleStats.remove(metric) }
      else  { vm.visibleStats.insert(metric) }
      if vm.subjectImage != nil { Task { await vm.compose() } }
    } label: {
      HStack {
        Image(systemName: on ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(on ? Color.creek : Color.white.opacity(0.3))
        Text(metric.rawValue)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(on ? .white : Color.white.opacity(0.4))
        Spacer()
        if on, let v = vm.averageValue(for: metric) {
          Text(String(format: "%.0f", v))
            .font(.mono(11)).foregroundStyle(Color.creek)
        }
      }
      .padding(10)
      .background(Color.white.opacity(on ? 0.08 : 0.03))
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
  }
  
  // MARK: - Action row
  
  private var actionRow: some View {
    HStack(spacing: 12) {
      Button {
        vm.saveToPhotos()
      } label: {
        Label("Save", systemImage: "square.and.arrow.down")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity, maxHeight: 44)
          .background(Color.white.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .disabled(vm.composited == nil)
      
      Button {
        vm.showShareSheet = true
      } label: {
        Label("Share", systemImage: "square.and.arrow.up")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity, maxHeight: 44)
          .background(Color.creek)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .disabled(vm.composited == nil)
    }
  }
}

// MARK: - Export filter enum

enum ExportFilter: String, CaseIterable, Identifiable {
  case none    = "Original"
  case vivid   = "Vivid"
  case noir    = "Noir"
  case chrome  = "Chrome"
  case fade    = "Fade"
  var id: String { rawValue }
  
  var previewGradient: LinearGradient {
    switch self {
    case .none:   return LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.15)], startPoint: .top, endPoint: .bottom)
    case .vivid:  return LinearGradient(colors: [.orange, .pink],   startPoint: .topLeading, endPoint: .bottomTrailing)
    case .noir:   return LinearGradient(colors: [.black, .gray],    startPoint: .top, endPoint: .bottom)
    case .chrome: return LinearGradient(colors: [.blue, .cyan],     startPoint: .topLeading, endPoint: .bottomTrailing)
    case .fade:   return LinearGradient(colors: [.white.opacity(0.4), .gray.opacity(0.2)], startPoint: .top, endPoint: .bottom)
    }
  }
  
  func apply(to image: CIImage) -> CIImage {
    switch self {
    case .none:   return image
    case .vivid:
      let f = CIFilter.vibrance(); f.inputImage = image; f.amount = 0.8
      return f.outputImage ?? image
    case .noir:
      let f = CIFilter.photoEffectNoir(); f.inputImage = image
      return f.outputImage ?? image
    case .chrome:
      let f = CIFilter.photoEffectChrome(); f.inputImage = image
      return f.outputImage ?? image
    case .fade:
      let f = CIFilter.photoEffectFade(); f.inputImage = image
      return f.outputImage ?? image
    }
  }
}

// MARK: - ViewModel

@MainActor
@Observable
final class WorkoutExportViewModel {
  
  private let samples: [WorkoutSample]
  
  var subjectImage   : UIImage?              = nil
  var composited     : UIImage?              = nil
  var selectedFilter  = ExportFilter.none
  var visibleStats   : Set<WorkoutMetric>    = [.heartRate, .speed, .altitude]
  var isProcessing    = false
  var processingStep  = ""
  var showPhotoPicker = false
  var showShareSheet  = false
  var showSavedAlert  = false
  
  private let ciContext = CIContext()
  
  init(samples: [WorkoutSample]) {
    self.samples = samples
  }
  
  // MARK: Average stats
  
  func averageValue(for metric: WorkoutMetric) -> Double? {
    let vals = samples.compactMap { metric.value(from: $0) }
    guard !vals.isEmpty else { return nil }
    return vals.reduce(0, +) / Double(vals.count)
  }
  
  // MARK: - Composition pipeline
  
  func compose() async {
    guard let subject = subjectImage else { return }
    isProcessing = true
    
    // 1. Render map snapshot
    processingStep = "Rendering map…"
    let mapSnap = await renderMapSnapshot(size: CGSize(width: 1080, height: 1080))
    
    // 2. Foreground separation via Vision
    processingStep = "Separating subject…"
    let masked = await separateForeground(from: subject, onto: mapSnap)
    
    // 3. Apply style filter to background
    processingStep = "Applying filter…"
    let styled = applyFilter(to: masked)
    
    // 4. Composite stats block
    processingStep = "Adding stats…"
    composited = drawStats(onto: styled)
    
    isProcessing = false
    processingStep = ""
  }
  
  // MARK: - Map snapshot
  
  private func renderMapSnapshot(size: CGSize) async -> UIImage {
    let coords  = samples.map(\.coordinate)
    guard !coords.isEmpty else { return UIImage() }
    
    let options = MKMapSnapshotter.Options()
    options.size = size
    options.scale = 1
    options.mapType = .mutedStandard
    let lats   = coords.map(\.latitude);  let lons = coords.map(\.longitude)
    let center = CLLocationCoordinate2D(latitude:  (lats.min()! + lats.max()!) / 2,
                                        longitude: (lons.min()! + lons.max()!) / 2)
    options.region = MKCoordinateRegion(
      center: center,
      span: MKCoordinateSpan(latitudeDelta:  (lats.max()! - lats.min()!) * 1.5,
                             longitudeDelta: (lons.max()! - lons.min()!) * 1.5))
    
    do {
      let snap = try await MKMapSnapshotter(options: options).start()
      UIGraphicsBeginImageContextWithOptions(size, false, 1)
      snap.image.draw(at: .zero)
      
      // Draw route polyline on snapshot
      let path = UIBezierPath()
      for (i, c) in coords.enumerated() {
        let pt = snap.point(for: c)
        i == 0 ? path.move(to: pt) : path.addLine(to: pt)
      }
      path.lineWidth = 3
      UIColor(Color.creek).setStroke()
      path.stroke()
      
      let result = UIGraphicsGetImageFromCurrentImageContext() ?? snap.image
      UIGraphicsEndImageContext()
      return result
    } catch {
      return UIImage()
    }
  }
  
  // MARK: - CoreML foreground separation
  
  private func separateForeground(from subject: UIImage,
                                  onto background: UIImage) async -> UIImage {
    guard let cgSubject = subject.cgImage else { return background }
    
    return await withCheckedContinuation { cont in
      let request = VNGenerateForegroundInstanceMaskRequest()
      let handler = VNImageRequestHandler(cgImage: cgSubject, options: [:])
      
      do {
        try handler.perform([request])
      } catch {
        cont.resume(returning: background)
        return
      }
      
      guard let result = request.results?.first,
            let maskBuffer = try? result.generateScaledMaskForImage(
              forInstances: result.allInstances, from: handler)
      else {
        cont.resume(returning: background)
        return
      }
      
      // Composite: background map → masked subject on top
      let maskCI    = CIImage(cvPixelBuffer: maskBuffer)
      let subjectCI = CIImage(cgImage: cgSubject)
        .transformed(by: CGAffineTransform(
          scaleX: background.size.width  / subject.size.width,
          y:      background.size.height / subject.size.height))
      
      let bgCI = CIImage(cgImage: background.cgImage ?? cgSubject)
      
      let blend = CIFilter.blendWithMask()
      blend.inputImage      = subjectCI
      blend.backgroundImage = bgCI
      blend.maskImage       = maskCI
      
      if let out = blend.outputImage,
         let cg  = ciContext.createCGImage(out, from: out.extent) {
        cont.resume(returning: UIImage(cgImage: cg))
      } else {
        cont.resume(returning: background)
      }
    }
  }
  
  // MARK: - Style filter
  
  private func applyFilter(to image: UIImage) -> UIImage {
    guard selectedFilter != .none,
          let cg = image.cgImage else { return image }
    let ci  = CIImage(cgImage: cg)
    let out = selectedFilter.apply(to: ci)
    guard let result = ciContext.createCGImage(out, from: out.extent) else { return image }
    return UIImage(cgImage: result)
  }
  
  // MARK: - Stats overlay
  
  private func drawStats(onto image: UIImage) -> UIImage {
    let size = image.size
    UIGraphicsBeginImageContextWithOptions(size, false, 1)
    image.draw(at: .zero)
    
    guard let ctx = UIGraphicsGetCurrentContext() else {
      let r = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
      return r ?? image
    }
    
    // Semi-transparent pill at bottom
    let pillH: CGFloat = 90
    let pillRect = CGRect(x: 16, y: size.height - pillH - 40,
                          width: size.width - 32, height: pillH)
    ctx.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
    let path = UIBezierPath(roundedRect: pillRect, cornerRadius: 16)
    path.fill()
    
    // Stats text
    let activeMetrics = WorkoutMetric.allCases.filter { visibleStats.contains($0) }
    let colW = pillRect.width / CGFloat(max(activeMetrics.count, 1))
    
    for (i, metric) in activeMetrics.enumerated() {
      guard let val = averageValue(for: metric) else { continue }
      let x = pillRect.minX + CGFloat(i) * colW
      let valStr  = String(format: "%.0f", val)
      let unitStr = metric.unit
      
      let valAttr: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 22, weight: .black),
        .foregroundColor: UIColor.white
      ]
      let unitAttr: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10, weight: .bold),
        .foregroundColor: UIColor.white.withAlphaComponent(0.5)
      ]
      let nameAttr: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 9, weight: .medium),
        .foregroundColor: UIColor.white.withAlphaComponent(0.4)
      ]
      
      let valSize  = (valStr  as NSString).size(withAttributes: valAttr)
      let nameSize = (metric.rawValue as NSString).size(withAttributes: nameAttr)
      let centreX  = x + colW / 2
      
      (metric.rawValue as NSString).draw(
        at: CGPoint(x: centreX - nameSize.width/2, y: pillRect.minY + 10),
        withAttributes: nameAttr)
      (valStr as NSString).draw(
        at: CGPoint(x: centreX - valSize.width/2, y: pillRect.minY + 26),
        withAttributes: valAttr)
      (unitStr as NSString).draw(
        at: CGPoint(x: centreX - 10, y: pillRect.minY + 58),
        withAttributes: unitAttr)
    }
    
    let result = UIGraphicsGetImageFromCurrentImageContext() ?? image
    UIGraphicsEndImageContext()
    return result
  }
  
  // MARK: - Save / share
  
  func saveToPhotos() {
    guard let img = composited else { return }
    PHPhotoLibrary.requestAuthorization { status in
      guard status == .authorized else { return }
      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: img)
      }) { [weak self] _, _ in
        DispatchQueue.main.async { self?.showSavedAlert = true }
      }
    }
  }
}

// MARK: - Helpers

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ImagePicker: UIViewControllerRepresentable {
  @Binding var image: UIImage?
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let p = UIImagePickerController()
    p.delegate = context.coordinator
    return p
  }
  func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
  class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: ImagePicker
    init(_ p: ImagePicker) { parent = p }
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      parent.image = info[.originalImage] as? UIImage
      picker.dismiss(animated: true)
    }
  }
}
