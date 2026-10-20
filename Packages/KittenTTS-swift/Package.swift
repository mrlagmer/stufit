// swift-tools-version: 5.9
// KittenSDK – on-device text-to-speech for iOS & macOS, powered by KittenTTS + ONNX Runtime.
//
// Vendored from https://github.com/KittenML/KittenTTS-swift @ 4da0abb
// (Apache 2.0). Local change: `.unsafeFlags(["-std=c++17"])` replaced with
// `cxxLanguageStandard: .cxx17`, which Xcode accepts from any package;
// test target dropped.


import PackageDescription

let package = Package(
    name: "KittenSDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "KittenTTS",
            targets: ["KittenTTS"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/microsoft/onnxruntime-swift-package-manager",
            from: "1.20.0"
        ),
    ],
    targets: [
        // Thin system-library shim that exposes <zlib.h> to Swift.
        .systemLibrary(
            name: "Czlib",
            path: "Sources/Czlib"
        ),

        // C++ phonemizer engine with C bridge for Swift interop.
        // Reads rule/dictionary data files to produce IPA output
        .target(
            name: "CEPhonemizer",
            path: "Sources/CEPhonemizer",
            sources: ["phonemizer.cpp", "swift_bridge.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .define("NDEBUG", .when(configuration: .release)),
            ]
        ),

        .target(
            name: "KittenTTS",
            dependencies: [
                "Czlib",
                "CEPhonemizer",
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager"),
            ],
            path: "Sources/KittenTTS"
        ),

    ],
    cxxLanguageStandard: .cxx17
)
