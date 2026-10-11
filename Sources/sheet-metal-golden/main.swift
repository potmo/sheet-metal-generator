// sheet-metal-golden
//
// Headless golden-output generator. Reproduces every output path of the sheet-metal-generator app
// (SVG / DXF / DXF baseplate / DXF all buttons and every on-screen CanvasView configuration) plus all
// ShapeMakers / DrawableObjects in sheet-metal-generator-lib, through a recording RenderTarget,
// DXFRenderTarget and SVGRenderTarget, for a fixed set of parameter scenarios.
//
// Usage: sheet-metal-golden --out <dir> [--normals <normals.json>] [--only <scenario>]
//
// Determinism notes:
//   * InputState persists through @AppStorage -> UserDefaults.standard. This tool's defaults domain is
//     its own process name ("sheet-metal-golden"), never the app's domain. It is wiped before and after
//     the run, every scenario sets every stored property explicitly and reads it back to verify.
//   * On-screen views are recorded with canvasSize 1000x800 and transform2d .identity
//     (zoom/pan is per-view UI state persisted by Canvas, not part of the model).
//   * DXF scripts get fixed relative file names so no machine paths end up in the output.

import CanvasRender
import CoreGraphics
import Foundation
@testable import sheet_metal_generator_lib
import simd

// MARK: - Arguments

var outDir: String?
var normalsPath = JsonNormals.defaultPath
var onlyScenario: String?
var listScenarios = false
// --quick: fast subset for iterating. "DXF all" renders only the first `quickBoxes` boxes of plate 1 and the
// (slow, ~3 min) baseplate export is skipped (BasePlateView is still covered by makers/BasePlateView-5x5).
var quick = false
let quickBoxes = 2
do {
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "--out": outDir = args.isEmpty ? nil : args.removeFirst()
        case "--normals": normalsPath = args.removeFirst()
        case "--only": onlyScenario = args.removeFirst()
        case "--list-scenarios": listScenarios = true
        case "--quick": quick = true
        default:
            // `-Key value` pairs are consumed by Foundation's NSArgumentDomain (e.g. -AppleLocale)
            if arg.hasPrefix("-"), !arg.hasPrefix("--"), !args.isEmpty {
                _ = args.removeFirst()
            } else {
                FileHandle.standardError.write("unknown argument \(arg)\n".data(using: .utf8)!)
                exit(2)
            }
        }
    }
}

guard listScenarios || outDir != nil else {
    FileHandle.standardError.write("usage: sheet-metal-golden --out <dir> [--normals <path>] [--only <scenario>]\n".data(using: .utf8)!)
    exit(2)
}

func log(_ string: String) {
    FileHandle.standardError.write((string + "\n").data(using: .utf8)!)
}

let outURL = URL(fileURLWithPath: outDir ?? ".")
var writtenFiles: [String] = []

func write(_ string: String, to relativePath: String) {
    let url = outURL.appendingPathComponent(relativePath)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! string.data(using: .utf8)!.write(to: url)
    writtenFiles.append(relativePath)
}

// MARK: - UserDefaults isolation

let storageKeys = [
    "size4", "height", "thickness", "bottomPlateThickness", "bend_radius", "gap_scalar", "hole_clearence",
    "fastener_thickness", "fastener_width", "k_factor", "angle_around_x", "angle_around_y", "angleSlerp",
    "cameraOrbit", "cameraTilt", "cameraDollySide", "cameraDollyup", "show_horizontal_flat_view",
    "show_top_aligned_flat_view", "show_folded_view", "show_3d_view", "fullscreen_top",
]

let defaultsDomain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
// golden.sh runs scenarios in parallel processes, each from a copy of the binary named
// "sheet-metal-golden-<scenario>", so every process gets its own private defaults domain.
guard defaultsDomain.hasPrefix("sheet-metal-golden") else {
    // never touch any other domain (e.g. the app's)
    log("refusing to run: unexpected defaults domain \(defaultsDomain)")
    exit(3)
}

func wipeOwnDefaults() {
    UserDefaults.standard.removePersistentDomain(forName: defaultsDomain)
    for key in storageKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

wipeOwnDefaults()
for key in storageKeys where UserDefaults.standard.object(forKey: key) != nil {
    log("UserDefaults key \(key) still resolves to \(UserDefaults.standard.object(forKey: key)!) after wiping (global/argument domain?) - aborting")
    exit(4)
}

// MARK: - Parameters

struct Params: Equatable {
    var size: Double
    var height: Double
    var thickness: Double
    var bottomPlateThickness: Double
    var bendRadius: Double
    var gapScalar: Double
    var holeClearence: Double
    var fastenerThickness: Double
    var fastenerWidth: Double
    var kFactor: Double
    var angleAroundX: Double
    var angleAroundY: Double
    var angleSlerp: Double
    var cameraOrbit: Double
    var cameraTilt: Double
    var cameraDollySide: Double
    var cameraDollyUp: Double
    var showHorizontalFlatView: Bool
    var showTopAlignedFlatView: Bool
    var showFolded: Bool
    var show3dView: Bool
    var fullScreenTop: Bool

    static let doubles: [(String, WritableKeyPath<Params, Double>, ReferenceWritableKeyPath<InputState, Double>)] = [
        ("size", \.size, \.size),
        ("height", \.height, \.height),
        ("thickness", \.thickness, \.thickness),
        ("bottomPlateThickness", \.bottomPlateThickness, \.bottomPlateThickness),
        ("bendRadius", \.bendRadius, \.bendRadius),
        ("gapScalar", \.gapScalar, \.gapScalar),
        ("holeClearence", \.holeClearence, \.holeClearence),
        ("fastenerThickness", \.fastenerThickness, \.fastenerThickness),
        ("fastenerWidth", \.fastenerWidth, \.fastenerWidth),
        ("kFactor", \.kFactor, \.kFactor),
        ("angleAroundX", \.angleAroundX, \.angleAroundX),
        ("angleAroundY", \.angleAroundY, \.angleAroundY),
        ("angleSlerp", \.angleSlerp, \.angleSlerp),
        ("cameraOrbit", \.cameraOrbit, \.cameraOrbit),
        ("cameraTilt", \.cameraTilt, \.cameraTilt),
        ("cameraDollySide", \.cameraDollySide, \.cameraDollySide),
        ("cameraDollyUp", \.cameraDollyUp, \.cameraDollyUp),
    ]

    static let bools: [(String, WritableKeyPath<Params, Bool>, ReferenceWritableKeyPath<InputState, Bool>)] = [
        ("showHorizontalFlatView", \.showHorizontalFlatView, \.showHorizontalFlatView),
        ("showTopAlignedFlatView", \.showTopAlignedFlatView, \.showTopAlignedFlatView),
        ("showFolded", \.showFolded, \.showFolded),
        ("show3dView", \.show3dView, \.show3dView),
        ("fullScreenTop", \.fullScreenTop, \.fullScreenTop),
    ]

    init(reading state: InputState) {
        size = state.size
        height = state.height
        thickness = state.thickness
        bottomPlateThickness = state.bottomPlateThickness
        bendRadius = state.bendRadius
        gapScalar = state.gapScalar
        holeClearence = state.holeClearence
        fastenerThickness = state.fastenerThickness
        fastenerWidth = state.fastenerWidth
        kFactor = state.kFactor
        angleAroundX = state.angleAroundX
        angleAroundY = state.angleAroundY
        angleSlerp = state.angleSlerp
        cameraOrbit = state.cameraOrbit
        cameraTilt = state.cameraTilt
        cameraDollySide = state.cameraDollySide
        cameraDollyUp = state.cameraDollyUp
        showHorizontalFlatView = state.showHorizontalFlatView
        showTopAlignedFlatView = state.showTopAlignedFlatView
        showFolded = state.showFolded
        show3dView = state.show3dView
        fullScreenTop = state.fullScreenTop
    }

    /// Sets every stored property explicitly and verifies the read-back.
    func apply(to state: InputState) {
        for (name, own, theirs) in Self.doubles {
            state[keyPath: theirs] = self[keyPath: own]
            guard state[keyPath: theirs] == self[keyPath: own] else {
                fatalError("state.\(name) did not stick")
            }
        }
        for (name, own, theirs) in Self.bools {
            state[keyPath: theirs] = self[keyPath: own]
            guard state[keyPath: theirs] == self[keyPath: own] else {
                fatalError("state.\(name) did not stick")
            }
        }
    }

    var dump: String {
        var lines: [String] = []
        for (name, own, _) in Self.doubles {
            lines.append("\(name) = \(self[keyPath: own])")
        }
        for (name, own, _) in Self.bools {
            lines.append("\(name) = \(self[keyPath: own])")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func with(_ change: (inout Params) -> Void) -> Params {
        var copy = self
        change(&copy)
        return copy
    }
}

/// A fresh InputState (like a freshly launched app), with every stored property set explicitly.
func makeState(_ params: Params) -> InputState {
    let state = InputState()
    params.apply(to: state)
    precondition(state.staticNormal == nil)
    return state
}

// Declared defaults: the domain is wiped, so a fresh InputState returns the defaults declared in code.
let declaredDefaults = Params(reading: InputState())

// dxfAllPlates: "DXF all" produces 8 plates (~250 MB) per scenario. The full loop is captured for
// a-defaults and b-angled; the other scenarios capture the first 2 plates (plate 1 uses size 25.9,
// plate 2+ the restored size - see the app's loop).
let scenarioPlateLimit: [String: Int] = ["c-folded-off-big": 2, "d-foldout-off-steep": 2, "e-only-xangle-thin": 2]

let scenarios: [(name: String, params: Params)] = [
    ("a-defaults", declaredDefaults),
    ("b-angled", declaredDefaults.with {
        $0.angleAroundX = 15
        $0.angleAroundY = -10
        $0.thickness = 1.5
        $0.bendRadius = 2.0
        $0.kFactor = 0.33
        $0.gapScalar = 2.0
        $0.angleSlerp = 0.5
        $0.cameraOrbit = 30
        $0.cameraTilt = 45
    }),
    ("c-folded-off-big", declaredDefaults.with {
        $0.showHorizontalFlatView = false
        $0.showTopAlignedFlatView = true
        $0.showFolded = false
        $0.show3dView = false
        $0.fullScreenTop = false
        $0.angleAroundX = -25
        $0.angleAroundY = 20
        $0.size = 40
        $0.height = 60
        $0.thickness = 0.8
        $0.bottomPlateThickness = 2.0
        $0.fastenerThickness = 0.5
        $0.fastenerWidth = 12
        $0.holeClearence = 0.1
        $0.bendRadius = 0.5
        $0.kFactor = 0.5
        $0.gapScalar = 3.0
        $0.angleSlerp = 1.0
        $0.cameraOrbit = -120
        $0.cameraTilt = -60
    }),
    ("d-foldout-off-steep", declaredDefaults.with {
        $0.showHorizontalFlatView = true
        $0.showTopAlignedFlatView = false
        $0.showFolded = true
        $0.angleAroundX = 40
        $0.angleAroundY = 0
        $0.size = 30
        $0.thickness = 2.0
        // NOTE: bendRadius = 0.0 makes FromSidesView produce NaN vertices -> LineSection fatalError
        // ("input is not valid") in the app as well, so a small non-zero radius is used.
        $0.bendRadius = 0.25
        $0.kFactor = 0.0
        $0.angleSlerp = 0.25
        $0.cameraOrbit = 180
        $0.cameraTilt = 90
        $0.cameraDollySide = 10
        $0.cameraDollyUp = -10
    }),
    ("e-only-xangle-thin", declaredDefaults.with {
        $0.angleAroundX = 0
        $0.angleAroundY = 33
        $0.thickness = 0.5
        $0.bendRadius = 5.0
        $0.kFactor = 1.0
        $0.gapScalar = 1.0
        $0.holeClearence = 0.5
        $0.angleSlerp = 0.75
        $0.cameraOrbit = 90
        $0.cameraTilt = 10
    }),
]

if listScenarios {
    // the "makers" pseudo scenario renders every ShapeMaker / DrawableObject through all backends
    print((scenarios.map(\.name) + ["makers"]).joined(separator: "\n"))
    wipeOwnDefaults()
    exit(0)
}
if let onlyScenario, !(scenarios.map(\.name) + ["makers"]).contains(onlyScenario) {
    log("unknown scenario \(onlyScenario)")
    exit(2)
}

let normals = JsonNormals.load(path: normalsPath)

// MARK: - App buttons (mirrors sheet-metal-generator.swift exactly, except file names)

func svgButton(state: InputState) -> String {
    let svgTarget = SVGRenderTarget()
    let maker = FromSidesView()
    let staticCamera = StaticCamera(position: Vector(0, 0, 200),
                                    rotation: Quat(angle: 0,
                                                   axis: Vector(0, 0, 1)))

    let renderTransform = OrthographicTransform(camera: staticCamera)
    let context = RenderContext(canvasSize: Vector2D(1000, 1000),
                                renderTarget: svgTarget,
                                transform2d: CGAffineTransform(scaleX: 1 / (25.4 / 72), y: 1 / (25.4 / 72)), // pixels to millimeters
                                transform3d: renderTransform)
    let shapes = maker.shapes(from: state)
    shapes.forEach { $0.draw(in: context) }

    return svgTarget.svg
}

func dxfButton(state: InputState) -> (String, DXFRenderTarget) {
    let dxfTarget = DXFRenderTarget()
    let maker = FromSidesView()

    let staticCamera = StaticCamera(position: Vector(0, 0, 200),
                                    rotation: Quat(angle: -.pi * 0.5, axis: Vector(1, 0, 0)))

    let renderTransform = OrthographicTransform(camera: staticCamera)
    let context = RenderContext(canvasSize: Vector2D(1000, 1000),
                                renderTarget: dxfTarget,
                                transform2d: CGAffineTransform(scaleX: 1, y: 1),
                                transform3d: renderTransform)
    let shapes = maker.shapes(from: state)
    shapes.forEach { $0.draw(in: context) }

    return (dxfTarget.dxf(), dxfTarget)
}

func dxfBaseplateButton(state: InputState) -> String {
    let dxfTarget = DXFRenderTarget()

    let oldSize = state.size
    let oldThickness = state.thickness
    state.size = 26.5
    state.thickness = 1.1
    let normals: [MirrorNormal] = normals

    let width = normals.filter { $0.mirror == 1 }.map(\.x).max() ?? 0
    let height = normals.filter { $0.mirror == 1 }.map(\.y).max() ?? 0

    let maker = BasePlateView(width: width + 1, height: height + 1)

    let staticCamera = StaticCamera(position: Vector(0, 0, 200),
                                    rotation: Quat(angle: -.pi * 0.5, axis: Vector(1, 0, 0)))

    let renderTransform = OrthographicTransform(camera: staticCamera)
    let context = RenderContext(canvasSize: Vector2D(1500, 1500),
                                renderTarget: dxfTarget,
                                transform2d: CGAffineTransform(scaleX: 1, y: 1),
                                transform3d: renderTransform)
    let shapes = maker.shapes(from: state)
    shapes.forEach { $0.draw(in: context) }

    let string = dxfTarget.dxf()

    state.size = oldSize
    state.thickness = oldThickness
    return string
}

/// Returns one script per plate, plus the labels placed on each plate (for the index file).
func dxfAllButton(state: InputState, maxPlates: Int = .max, maxBoxes: Int = .max) -> [(script: String, labels: [String])] {
    var results: [(script: String, labels: [String])] = []

    let oldSize = state.size
    state.size = 25.9

    var normals: [MirrorNormal] = normals

    normals.sort(by: { a, b in
        if a.mirror != b.mirror {
            return a.mirror < b.mirror
        } else if a.x != b.x {
            return a.x < b.x
        }
        return a.y < b.y
    })

    let width = 35
    let height = 21
    var planeNumber = 0
    var boxCount = 0

    while !normals.isEmpty, planeNumber < maxPlates, boxCount < maxBoxes {
        let dxfTarget = DXFRenderTarget()
        let maker = FromSidesView()
        var labels: [String] = []

        planeNumber += 1
        outer: for y in 0 ... height {
            for x in 0 ... width {
                guard let mirror: MirrorNormal = normals.first, boxCount < maxBoxes else {
                    break outer
                }
                boxCount += 1
                normals.removeFirst()

                let state = state
                state.firstLabel = "\(mirror.mirror)" + "\(mirror.x)".leftpad(to: 2, with: "0") + "\(mirror.y)".leftpad(to: 2, with: "0")
                state.staticNormal = mirror.normal

                let staticCamera = StaticCamera(position: Vector(0, 0, 200),
                                                rotation: Quat(angle: -.pi * 0.5, axis: Vector(1, 0, 0)))

                let renderTransform = OrthographicTransform(camera: staticCamera)
                let context = RenderContext(canvasSize: Vector2D(1000, 1000),
                                            renderTarget: dxfTarget,
                                            transform2d: CGAffineTransform(scaleX: 1, y: 1),
                                            transform3d: renderTransform)

                let dist = 80.0
                let xOffset = 30.0 + dist / 2.0 + Double(x) * dist + (y.isMultiple(of: 2) ? 0.0 : (dist / 2.0))
                let yOffset = 30.0 + dist / 2.0 + Double(y) * dist * 0.8
                let shapes = Offset(Vector(xOffset, -yOffset, 0)) {
                    for shape in maker.shapes(from: state) {
                        shape
                    }
                }
                shapes.draw(in: context)
                dxfTarget.finishGroup()

                labels.append("\(x),\(y) size=\(state.size) label=\(state.firstLabel)")
            }
        }

        let string = dxfTarget.dxf()
        results.append((string, labels))
        log("  dxf all: plate \(planeNumber) done, \(normals.count) normals left")

        // NOTE: the app restores the size inside the while loop, so only plate 1 uses size 25.9.
        state.size = oldSize
    }

    return results
}

/// The PDF's page count and size; the bytes themselves contain the creation date.
func pdfSummary(_ data: Data) -> String {
    guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider), let page = document.page(at: 1) else {
        return "invalid PDF\n"
    }
    let box = page.getBoxRect(.mediaBox)
    return String(format: "pages %d\nmediaBox %.3f %.3f %.3f %.3f\n", document.numberOfPages, box.minX, box.minY, box.width, box.height)
}

// MARK: - On-screen views

let viewCanvasSize = Vector2D(1000, 800)

func record(maker: any ShapeMaker<InputState>, state: InputState, transform: RenderTransformer, canvasSize: Vector2D = viewCanvasSize) -> String {
    let target = RecordingRenderTarget()
    let shapes = maker.shapes(from: state)
    let context = RenderContext(canvasSize: canvasSize,
                                renderTarget: target,
                                transform2d: .identity,
                                transform3d: transform)
    shapes.forEach { $0.draw(in: context) }
    return target.text
}

func appViewConfigurations(state: InputState) -> [(name: String, transform: RenderTransformer)] {
    var result: [(name: String, transform: RenderTransformer)] = []
    // singleView, show3dView == true
    result.append(("view-single-3d", OrthographicTransform(camera: StateObjectCamera(state: state))))
    // singleView, show3dView == false
    result.append(("view-single-static", OrthographicTransform(camera: StaticCamera(position: Vector(0, 0, 20),
                                                                                    rotation: Quat(angle: -.pi * 0.5, axis: Vector(1, 0, 0))))))
    // multiView: top
    result.append(("view-multi-top", OrthographicTransform(camera: StaticCamera(position: Vector(0, 0, 200),
                                                                                rotation: Quat(angle: .pi / 2,
                                                                                               axis: Vector(-1, 0, 0))))))
    // multiView: front
    do {
        let cameraOrbit = Quat(angle: 0, axis: Vector(0, 0, 1))
        let cameraTilt = Quat(angle: .pi / 2, axis: cameraOrbit.act(Vector(1, 0, 0)))
        result.append(("view-multi-front", OrthographicTransform(camera: StaticCamera(position: Vector(0, 0, 200),
                                                                                      rotation: cameraTilt * cameraOrbit))))
    }
    // multiView: left
    do {
        let cameraOrbit = Quat(angle: -.pi / 2, axis: Vector(0, 0, 1))
        let cameraTilt = Quat(angle: .pi / 2, axis: cameraOrbit.act(Vector(1, 0, 0)))
        result.append(("view-multi-left", OrthographicTransform(camera: StaticCamera(position: Vector(0, 0, 200),
                                                                                     rotation: cameraTilt * cameraOrbit))))
    }
    // multiView: orbit
    result.append(("view-multi-orbit", OrthographicTransform(camera: StateObjectCamera(state: state))))
    return result
}

// MARK: - Run scenarios

var debugDXFTarget: DXFRenderTarget?

for scenario in scenarios {
    if let onlyScenario, onlyScenario != scenario.name {
        continue
    }
    let dir = scenario.name
    log("scenario \(dir)")
    write(scenario.params.dump, to: "\(dir)/params.txt")

    // SVG button
    write(svgButton(state: makeState(scenario.params)), to: "\(dir)/button-svg.svg")

    // DXF button
    let (dxf, dxfTarget) = dxfButton(state: makeState(scenario.params))
    write(dxf, to: "\(dir)/button-dxf.dxf")
    write(pdfSummary(dxfTarget.pdf()), to: "\(dir)/button-dxf.pdf.txt")
    if debugDXFTarget == nil {
        debugDXFTarget = dxfTarget
    }

    // DXF baseplate button (also verify it restores size/thickness like the app)
    if !quick {
        let state = makeState(scenario.params)
        write(dxfBaseplateButton(state: state), to: "\(dir)/button-dxf-baseplate.dxf")
        precondition(state.size == scenario.params.size && state.thickness == scenario.params.thickness)
    }

    // DXF all button
    do {
        let state = makeState(scenario.params)
        let plates = quick
            ? dxfAllButton(state: state, maxPlates: 1, maxBoxes: quickBoxes)
            : dxfAllButton(state: state, maxPlates: scenarioPlateLimit[scenario.name] ?? .max)
        var index: [String] = []
        for (plateIndex, plate) in plates.enumerated() {
            let name = String(format: "button-dxf-all-plate-%02d.dxf", plateIndex + 1)
            write(plate.script, to: "\(dir)/\(name)")
            index.append("# \(name)")
            index.append(contentsOf: plate.labels)
        }
        write(index.joined(separator: "\n") + "\n", to: "\(dir)/button-dxf-all-index.txt")

        // The app keeps using the same state object after "DXF all": staticNormal/firstLabel stay set.
        // Capture the SVG/DXF buttons and the static single view in that post-"DXF all" state too.
        if scenario.name == "a-defaults" {
            write("staticNormal = \(state.staticNormal.map { "\($0.x), \($0.y), \($0.z)" } ?? "nil")\nfirstLabel = \(state.firstLabel)\n" + Params(reading: state).dump,
                  to: "\(dir)/after-dxf-all/params.txt")
            write(svgButton(state: state), to: "\(dir)/after-dxf-all/button-svg.svg")
            write(dxfButton(state: state).0, to: "\(dir)/after-dxf-all/button-dxf.dxf")
            for view in appViewConfigurations(state: state) {
                write(record(maker: FromSidesView(), state: state, transform: view.transform), to: "\(dir)/after-dxf-all/\(view.name).rec.txt")
            }
        }
    }

    // On-screen CanvasView configurations
    do {
        let state = makeState(scenario.params)
        for view in appViewConfigurations(state: state) {
            write(record(maker: FromSidesView(), state: state, transform: view.transform), to: "\(dir)/\(view.name).rec.txt")
        }
        // Guard against anything else having written to this process' defaults domain meanwhile.
        guard Params(reading: state) == scenario.params else {
            fatalError("persisted state changed during scenario \(scenario.name) - another process sharing the defaults domain?")
        }
    }
}

// MARK: - All makers / drawable objects through all three backends

struct OrtographicSheetMaker: ShapeMaker {
    typealias StateType = InputState

    func shapes(from state: InputState) -> [any DrawableShape] {
        let normal = Vector(0.2, -0.1, 1).normalized
        let base = Plane(fitting: 20, normal: normal).extrude(thickness: 1.0)
        let bendNorth = Bend(from: base.northFace, angle: .pi / 2, radius: 1.0, kFactor: 0.44)
        let bendWest = Bend(from: base.westFace, angle: .pi / 3, radius: 2.0, kFactor: 0.3)
        let sheet = Sheet(top: base.top,
                          bottom: base.bottom,
                          thickness: base.thickness,
                          northSide: .bend(bendNorth),
                          eastSide: .extrusion(base.extrudedEast(5)),
                          southSide: .solid,
                          westSide: .bend(bendWest))
        return [
            OrtographicSheet(sheet: sheet),
            Offset(Vector(40, 0, 0)) {
                OrtographicSheet(sheet: Plane(fitting: 15, normal: Vector(0, 0, 1)).extrude(thickness: 2.0).extrudedNorth(3).extrudedSouth(2).extrudedWest(1))
            },
        ]
    }
}

func runMakers() {
    guard let debugDXFTarget else { fatalError("no dxf target for DXFLineDrawerDebug") }
    let state = makeState(declaredDefaults)

    let makers: [(name: String, maker: any ShapeMaker<InputState>)] = [
        ("FromSidesView", FromSidesView()),
        ("BasePlateView-5x5", BasePlateView(width: 5, height: 5)),
        ("NumberTestView", NumberTestView()),
        ("OrbitTestView", OrbitTestView()),
        ("OrtographicSheet", OrtographicSheetMaker()),
        ("DXFLineDrawerDebug", DXFLineDrawerDebug(target: debugDXFTarget)),
    ]

    let exportCamera = StaticCamera(position: Vector(0, 0, 200),
                                    rotation: Quat(angle: -.pi * 0.5, axis: Vector(1, 0, 0)))
    let obliqueOrbit = Quat(angle: 30.0.degreesToRadians, axis: Vector(0, 0, 1))
    let obliqueCamera = StaticCamera(position: Vector(0, 0, 0),
                                     rotation: Quat(angle: -45.0.degreesToRadians, axis: obliqueOrbit.act(Vector(1, 0, 0))) * obliqueOrbit)

    let recordingTransforms: [(String, RenderTransformer)] = [
        ("ortho-export-camera", OrthographicTransform(camera: exportCamera)),
        ("ortho-oblique", OrthographicTransform(camera: obliqueCamera)),
        ("axis-xy", AxisAlignedOrthographicTransform(plane: .xy)),
        ("axis-xz", AxisAlignedOrthographicTransform(plane: .xz)),
        ("axis-yz", AxisAlignedOrthographicTransform(plane: .yz)),
        ("perspective-export-camera", PerspectiveTransform(camera: exportCamera)),
    ]

    for (name, maker) in makers {
        log("maker \(name)")
        let dir = "makers/\(name)"
        for (transformName, transform) in recordingTransforms {
            write(record(maker: maker, state: state, transform: transform), to: "\(dir)/rec-\(transformName).rec.txt")
        }

        // SVG backend, with the SVG button's camera and transform2d
        do {
            let svgTarget = SVGRenderTarget()
            let context = RenderContext(canvasSize: Vector2D(1000, 1000),
                                        renderTarget: svgTarget,
                                        transform2d: CGAffineTransform(scaleX: 1 / (25.4 / 72), y: 1 / (25.4 / 72)),
                                        transform3d: OrthographicTransform(camera: StaticCamera(position: Vector(0, 0, 200),
                                                                                                rotation: Quat(angle: 0, axis: Vector(0, 0, 1)))))
            maker.shapes(from: state).forEach { $0.draw(in: context) }
            write(svgTarget.svg, to: "\(dir)/svg-button-camera.svg")
        }
        // SVG backend, with the export camera and identity transform2d
        do {
            let svgTarget = SVGRenderTarget()
            let context = RenderContext(canvasSize: Vector2D(1000, 1000),
                                        renderTarget: svgTarget,
                                        transform2d: .identity,
                                        transform3d: OrthographicTransform(camera: exportCamera))
            maker.shapes(from: state).forEach { $0.draw(in: context) }
            write(svgTarget.svg, to: "\(dir)/svg-export-camera.svg")
        }

        // DXF backend, with the DXF button's camera/transform2d
        do {
            let dxfTarget = DXFRenderTarget()
            let context = RenderContext(canvasSize: Vector2D(1000, 1000),
                                        renderTarget: dxfTarget,
                                        transform2d: CGAffineTransform(scaleX: 1, y: 1),
                                        transform3d: OrthographicTransform(camera: exportCamera))
            maker.shapes(from: state).forEach { $0.draw(in: context) }
            write(dxfTarget.dxf(), to: "\(dir)/dxf-export-camera.dxf")
        }
    }
}

if onlyScenario == nil || onlyScenario == "makers" {
    if debugDXFTarget == nil {
        debugDXFTarget = dxfButton(state: makeState(declaredDefaults)).1
    }
    runMakers()
}

// MARK: - Manifest

let localeSample = (-1234.56789).toFixed(5)
let manifest = """
sheet-metal-golden manifest
view canvasSize = 1000x800, transform2d = identity
locale = \(Locale.current.identifier)
toFixed(-1234.56789, 5) = \(localeSample) utf8=\(Array(localeSample.utf8).map { String($0) }.joined(separator: ","))
normals = \(normals.count) entries (file: Sources/sheet-metal-generator-exec/Resources/normals.json)
files:
\(writtenFiles.sorted().joined(separator: "\n"))

"""
write(manifest, to: "MANIFEST-\(onlyScenario ?? "all").txt")

wipeOwnDefaults()
log("wrote \(writtenFiles.count) files to \(outURL.path)")
