#!/usr/bin/env swift
//
// generate_icon.swift
//
// Renders a 1024x1024 PNG app icon at the given path. Used by CI to produce a
// placeholder so the build doesn't break before a designed icon lands.
//
// Usage: swift scripts/generate_icon.swift path/to/AppIcon-1024.png

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("Usage: generate_icon.swift <output.png>\n".utf8))
    exit(2)
}
let outPath = CommandLine.arguments[1]

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

guard let ctx = CGContext(
    data: nil,
    width: size, height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo
) else {
    fputs("Could not create CGContext\n", stderr)
    exit(1)
}

// Background — vertical gradient close to brand accent (Pathivu green)
let gradColors = [
    CGColor(red: 0.18, green: 0.49, blue: 0.36, alpha: 1.0),
    CGColor(red: 0.10, green: 0.33, blue: 0.26, alpha: 1.0)
] as CFArray
guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: [0, 1]) else {
    exit(1)
}
ctx.drawLinearGradient(
    gradient,
    start: .zero,
    end: CGPoint(x: 0, y: size),
    options: []
)

// Soft glass ring
ctx.saveGState()
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
ctx.setLineWidth(28)
ctx.strokeEllipse(in: CGRect(x: 110, y: 110, width: 804, height: 804))
ctx.restoreGState()

// Monogram "P" centered
let font = NSFont.systemFont(ofSize: 640, weight: .heavy)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .kern: -6
]
let mono = NSAttributedString(string: "P", attributes: attrs)

let line = CTLineCreateWithAttributedString(mono)
let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
let x = (CGFloat(size) - bounds.width) / 2 - bounds.minX
let y = (CGFloat(size) - bounds.height) / 2 - bounds.minY

ctx.textPosition = CGPoint(x: x, y: y)
CTLineDraw(line, ctx)

// Encode PNG
guard let cgImage = ctx.makeImage() else {
    fputs("Could not snapshot image\n", stderr)
    exit(1)
}

let outURL = URL(fileURLWithPath: outPath)
try? FileManager.default.createDirectory(
    at: outURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let dest = CGImageDestinationCreateWithURL(
    outURL as CFURL, UTType.png.identifier as CFString, 1, nil
) else {
    fputs("Could not create image destination\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(dest, cgImage, nil)
guard CGImageDestinationFinalize(dest) else {
    fputs("Could not finalize PNG\n", stderr)
    exit(1)
}

print("Wrote \(outPath)")
