// swift-tools-version:6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let darwinPlatforms: [Platform] = [
    .iOS,
    .macOS,
    .macCatalyst,
    .tvOS,
    .visionOS,
    .watchOS,
]
var swiftSettings: [SwiftSetting] = [
    .define("SQLITE_ENABLE_FTS5"),
    .define("SQLITE_ENABLE_SNAPSHOT"),
    // Not all Linux distributions have support for WAL snapshots.
    .define("SQLITE_DISABLE_SNAPSHOT", .when(platforms: [.linux])),
]
var cSettings: [CSetting] = []
var dependencies: [PackageDescription.Package.Dependency] = []

// Don't rely on those environment variables. They are ONLY testing conveniences:
// $ SQLITE_ENABLE_PREUPDATE_HOOK=1 make test_SPM
if ProcessInfo.processInfo.environment["SQLITE_ENABLE_PREUPDATE_HOOK"] == "1" {
    swiftSettings.append(.define("SQLITE_ENABLE_PREUPDATE_HOOK"))
    cSettings.append(.define("GRDB_SQLITE_ENABLE_PREUPDATE_HOOK"))
}

// The SPI_BUILDER environment variable enables documentation building
// on <https://swiftpackageindex.com/groue/GRDB.swift>. See
// <https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2122>
// for more information.
//
// SPI_BUILDER also enables the `make docs-localhost` command.
if ProcessInfo.processInfo.environment["SPI_BUILDER"] == "1" {
    dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"))
}

// GRDB+SQLCipher: Uncomment those lines
//dependencies.append(.package(url: "https://github.com/sqlcipher/SQLCipher.swift.git", from: "4.11.0"))
//cSettings.append(.define("SQLITE_HAS_CODEC"))
//swiftSettings.append(.define("SQLITE_HAS_CODEC"))
//swiftSettings.append(.define("SQLCipher"))

// Custom SQLite (binary xcframework) shared by GRDBSQLite, GRDB, and consuming apps.
// SwiftPM package identity from this URL is `sqlite-pipeline`.
// Use `branch:` while iterating; pin with `from:` / `exact:` / `revision:` for reproducible builds.
dependencies.append(
    .package(url: "https://github.com/plangrid/sqlite-pipeline.git", from: "1.0.0")
)

let package = Package(
    name: "GRDB",
    defaultLocalization: "en", // for tests
    platforms: [
        .iOS(.v13),
        // Must be >= sqlite-pipeline macOS (.v11) because GRDB / GRDBSQLite link its sqlite3 product.
        .macOS(.v11),
        .tvOS(.v13),
        .watchOS(.v7),
    ],
    products: [
        // GRDB+SQLCipher: Delete the GRDBSQLite library
        .library(name: "GRDBSQLite", targets: ["GRDBSQLite"]),
        .library(name: "GRDB", targets: ["GRDB"]),
        .library(name: "GRDB-dynamic", type: .dynamic, targets: ["GRDB"]),
    ],
    dependencies: dependencies,
    targets: [
        // GRDB+SQLCipher: Delete the GRDBSQLite target
        .target(
            name: "GRDBSQLite",
            dependencies: [
                .product(name: "sqlite3", package: "sqlite-pipeline"),
            ],
//            path: "Sources/GRDBSQLite",
//            sources: ["shim.c"],
//            publicHeadersPath: "include"
        ),
        // GRDB+SQLCipher: Uncomment the GRDBSQLCipher target
        //.target(
        //    name: "GRDBSQLCipher",
        //    dependencies: [.product(name: "SQLCipher", package: "SQLCipher.swift")]
        //),
        .target(
            name: "GRDB",
            dependencies: [
                // GRDB+SQLCipher: Delete the GRDBSQLite dependency
                .target(name: "GRDBSQLite"),
                // Same sqlite3 binary as GRDBSQLite so Swift `import GRDBSQLite` and any
                // C headers (`<sqlite3.h>`) resolve to one image (avoids system SQLite).
                .product(name: "sqlite3", package: "sqlite-pipeline"),
                // GRDB+SQLCipher: Uncomment the SQLCipher and GRDBSQLCipher dependencies
                //.product(name: "SQLCipher", package: "SQLCipher.swift"),
                //.target(name: "GRDBSQLCipher"),
            ],
            path: "GRDB",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            cSettings: cSettings,
            swiftSettings: swiftSettings),
        .testTarget(
            name: "GRDBTests",
            dependencies: ["GRDB"],
            path: "Tests",
            exclude: [
                "CocoaPods",
                "Crash",
                "CustomSQLite",
                "GRDBManualInstall",
                "GRDBTests/getThreadsCount.c",
                "Info.plist",
                "Performance",
                "SPM",
                "Swift6Migration",
                "generatePerformanceReport.rb",
                "parsePerformanceTests.rb",
            ],
            resources: [
                .copy("GRDBTests/Betty.jpeg"),
                .copy("GRDBTests/InflectionsTests.json"),
                .copy("GRDBTests/Issue1383.sqlite"),
                .copy("GRDBTests/db.SQLCipher3"),
            ],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                // Tests still use the Swift 5 language mode.
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
            ])
    ],
    swiftLanguageModes: [.v6]
)
