// swift-tools-version: 6.2
import PackageDescription

// Modo estrito: Swift 6 (concorrência completa) e aviso tratado como erro.
let rigor: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "CaptaNucleo",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CaptaNucleo", targets: ["CaptaNucleo"]),
        .library(name: "CaptaSistema", targets: ["CaptaSistema"]),
    ],
    targets: [
        .target(name: "CaptaNucleo", swiftSettings: rigor),
        .target(name: "CaptaSistema", dependencies: ["CaptaNucleo"], swiftSettings: rigor),
        .testTarget(
            name: "CaptaNucleoTests",
            dependencies: ["CaptaNucleo", "CaptaSistema"],
            swiftSettings: rigor
        ),
    ],
    swiftLanguageModes: [.v6]
)
