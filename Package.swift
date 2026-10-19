// swift-tools-version:5.9
//
//  Package.swift
//  BYScrollView
//

import PackageDescription

let package = Package(
    name: "BYScrollView",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "BYScrollView",
            targets: ["BYScrollView"]
        )
    ],
    targets: [
        .target(name: "BYScrollView")
    ]
)