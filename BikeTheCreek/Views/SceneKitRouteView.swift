//
//  SceneKitRouteView.swift
//  BikeTheCreek
//
//  Created by Ashesh Patel on 2026-06-06.
//


//
//  SceneKitRouteView.swift
//  BikeTheCreek
//
//  3D SceneKit route visualisation.
//  - Segments coloured by HR zone
//  - Altitude extruded on Y axis
//  - Animated fade-in trail effect
//  - Orbit / pinch / pan gesture controls
//

import SceneKit
import SwiftUI
internal import _LocationEssentials

struct SceneKitRouteView: View {

    let samples: [WorkoutSample]
    @State private var vm = SceneKitRouteViewModel()

    var body: some View {
        ZStack {
            SceneView(scene: vm.scene,
                      pointOfView: vm.cameraNode,
                      options: [.allowsCameraControl, .autoenablesDefaultLighting])
                .ignoresSafeArea()
                .onAppear { vm.build(from: samples) }
                .onChange(of: samples.count) { _, _ in vm.build(from: samples) }

            VStack {
                Spacer()
                legendBar
                    .padding(.bottom, 40)
            }
        }
        .navigationTitle("3D Route")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var legendBar: some View {
        HStack(spacing: 0) {
            ForEach(HRZone.allCases, id: \.rawValue) { zone in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(zone.color))
                        .frame(width: 36, height: 10)
                    Text("Z\(zone.rawValue + 1)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class SceneKitRouteViewModel {

    let scene      = SCNScene()
    let cameraNode = SCNNode()

    private var routeNode: SCNNode?

    init() {
        setupScene()
    }

    // MARK: - Scene setup

    private func setupScene() {
        scene.background.contents = UIColor(white: 0.05, alpha: 1)

        // Camera
        let cam = SCNCamera()
        cam.zFar = 10_000
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 80, 200)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)

        // Ambient light
        let amb = SCNNode(); amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.color = UIColor(white: 0.3, alpha: 1)
        scene.rootNode.addChildNode(amb)

        // Directional light
        let dir = SCNNode(); dir.light = SCNLight()
        dir.light?.type = .directional
        dir.light?.color = UIColor(white: 0.9, alpha: 1)
        dir.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)
        scene.rootNode.addChildNode(dir)

        // Ground grid
        let grid = SCNFloor()
        grid.reflectivity = 0.05
        grid.firstMaterial?.diffuse.contents = UIColor(white: 0.1, alpha: 1)
        let gridNode = SCNNode(geometry: grid)
        scene.rootNode.addChildNode(gridNode)
    }

    // MARK: - Route building

    func build(from samples: [WorkoutSample]) {
        routeNode?.removeFromParentNode()
        guard samples.count > 1 else { return }

        let root = SCNNode()
        let coords = samples.map { $0.coordinate }

        // Normalise to scene space
        let latC  = coords.map(\.latitude).reduce(0,+)  / Double(coords.count)
        let lonC  = coords.map(\.longitude).reduce(0,+) / Double(coords.count)
        let scale = 8_000.0   // degrees → scene units

        let altValues = samples.compactMap(\.altitude)
        let altMin    = altValues.min() ?? 0
        let altScale  = 0.15

        func pos(_ s: WorkoutSample, idx: Int) -> SCNVector3 {
            let x = Float((s.coordinate.longitude - lonC) * scale)
            let z = Float((s.coordinate.latitude  - latC) * scale)
            let y = Float(((s.altitude ?? altMin) - altMin) * altScale)
            return SCNVector3(x, y, -z)
        }

        // Build tube segments between consecutive samples
        for i in 0..<samples.count - 1 {
            let a = samples[i]; let b = samples[i+1]
            let pA = pos(a, idx: i); let pB = pos(b, idx: i+1)

            let zone  = a.heartRate.map { HRZone.zone(for: $0) } ?? .zone1
            let seg   = tubeBetween(pA, pB, color: zone.color, radius: 0.6)

            // Fade-in animation staggered by index
            seg.opacity = 0
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0; fade.toValue = 1
            fade.duration  = 0.4
            fade.beginTime = CACurrentMediaTime() + Double(i) * 0.003
            fade.fillMode  = .forwards
            fade.isRemovedOnCompletion = false
            seg.addAnimation(fade, forKey: "fade")

            root.addChildNode(seg)
        }

        // Start / finish spheres
        if let first = samples.first {
            let sp = SCNSphere(radius: 2)
            sp.firstMaterial?.diffuse.contents = UIColor.systemGreen
            let n = SCNNode(geometry: sp); n.position = pos(first, idx: 0)
            root.addChildNode(n)
        }
        if let last = samples.last {
            let sp = SCNSphere(radius: 2)
            sp.firstMaterial?.diffuse.contents = UIColor.systemRed
            let n = SCNNode(geometry: sp); n.position = pos(last, idx: samples.count-1)
            root.addChildNode(n)
        }

        scene.rootNode.addChildNode(root)
        routeNode = root

        // Re-frame camera
        let xs = samples.indices.map { Float((samples[$0].coordinate.longitude - lonC) * scale) }
        let span = (xs.max() ?? 1) - (xs.min() ?? 0)
        cameraNode.position = SCNVector3(0, span * 0.5, span * 1.0)
        cameraNode.look(at: SCNVector3(0, 0, 0))
    }

    // MARK: - Helpers

    private func tubeBetween(_ a: SCNVector3, _ b: SCNVector3,
                              color: UIColor, radius: CGFloat) -> SCNNode {
        let dx = b.x - a.x; let dy = b.y - a.y; let dz = b.z - a.z
        let length = sqrt(dx*dx + dy*dy + dz*dz)
        guard length > 0 else { return SCNNode() }
        let cyl    = SCNCylinder(radius: radius, height: CGFloat(length))
        cyl.firstMaterial?.diffuse.contents = color
        cyl.firstMaterial?.lightingModel     = .phong
        let node = SCNNode(geometry: cyl)
        node.position = SCNVector3((a.x+b.x)/2, (a.y+b.y)/2, (a.z+b.z)/2)

        // Rotate cylinder to point from a → b
        let up = SCNVector3(0,1,0)
        let dir = SCNVector3(dx/length, dy/length, dz/length)
        let axis = SCNVector3(up.y*dir.z - up.z*dir.y,
                              up.z*dir.x - up.x*dir.z,
                              up.x*dir.y - up.y*dir.x)
        let dot  = up.x*dir.x + up.y*dir.y + up.z*dir.z
        let ang  = acos(max(-1, min(1, dot)))
        node.rotation = SCNVector4(axis.x, axis.y, axis.z, ang)
        return node
    }
}
