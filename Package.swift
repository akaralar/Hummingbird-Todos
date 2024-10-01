// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Todos",
	platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17)],
	products: [
		.executable(name: "App", targets: ["App"]),
	],
	dependencies: [
		.package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
	],
	targets: [
		.executableTarget(
			name: "App",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				.product(name: "Hummingbird", package: "hummingbird"),
			],
			path: "Sources/App",
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency")
  			]
		),
		.testTarget(
			name: "AppTests",
			dependencies: [
				.byName(name: "App"),
				.product(name: "HummingbirdTesting", package: "hummingbird")
			],
			path: "Tests/AppTests"
		)
	]
)
