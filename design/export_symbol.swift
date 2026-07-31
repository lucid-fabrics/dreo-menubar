#!/usr/bin/env swift
//
// Renders an SF Symbol to a PNG, so the App Store screenshots can show the SAME
// glyph the app puts in the menu bar.
//
// This exists because the screenshots used to composite the colour app icon into
// the menu bar strip, while WindbarApp.swift actually renders
// Image(systemName: appModel.menuBarSymbol), a monochrome template symbol. Anyone
// running the app saw a different menu bar than the store page promised, which is
// both a lie and a 2.3.3 metadata-mismatch risk.
//
//   swift design/export_symbol.swift fan.fill 34 white out.png
//
import AppKit

let args = CommandLine.arguments
guard args.count == 5, let size = Double(args[2]) else {
    let usage = "usage: export_symbol.swift <symbol> <points> <white|black> <out.png>\n"
    FileHandle.standardError.write(Data(usage.utf8))
    exit(2)
}
let (name, tint, outPath) = (args[1], args[3], args[4])

guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
    FileHandle.standardError.write(Data("No such SF Symbol: \(name)\n".utf8))
    exit(1)
}

// Match how the menu bar renders it: semibold weight, one flat colour, no shadow.
let configured = symbol.withSymbolConfiguration(
    .init(pointSize: size, weight: .semibold, scale: .medium)) ?? symbol
let box = configured.size
let colour: NSColor = tint == "black" ? .black : .white

let canvas = NSImage(size: box)
canvas.lockFocus()
colour.set()
NSRect(origin: .zero, size: box).fill(using: .sourceOver)
configured.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1)
canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Could not encode PNG\n".utf8))
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outPath))
print("\(name) -> \(outPath) (\(Int(box.width))x\(Int(box.height)))")
