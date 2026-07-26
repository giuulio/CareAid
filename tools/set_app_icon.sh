#!/bin/bash
# Install a source image as the CareAid app icon. Offline, never deployed.
#
#   tools/set_app_icon.sh ~/Desktop/careaid-mark.png
#
# Scales to 1024x1024 and flattens onto white, because an iOS app icon must be
# exactly that size and must not carry an alpha channel. The flatten goes
# through CoreGraphics rather than a JPEG round-trip so the flat-colour edges
# stay clean.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <source-image>" >&2
  exit 1
fi

SRC="$1"
if [ ! -f "$SRC" ]; then
  echo "no such file: $SRC" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/CareAid/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/flatten.swift" <<'SWIFT'
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let src = URL(fileURLWithPath: CommandLine.arguments[1])
let dst = URL(fileURLWithPath: CommandLine.arguments[2])
let side = 1024

guard let source = CGImageSourceCreateWithURL(src as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write("cannot read \(src.path)\n".data(using: .utf8)!)
    exit(1)
}

guard let ctx = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    FileHandle.standardError.write("cannot create context\n".data(using: .utf8)!)
    exit(1)
}

let full = CGRect(x: 0, y: 0, width: side, height: side)
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(full)
ctx.interpolationQuality = .high
ctx.draw(image, in: full)

guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(dst as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write("cannot write \(dst.path)\n".data(using: .utf8)!)
    exit(1)
}
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write("cannot finalize \(dst.path)\n".data(using: .utf8)!)
    exit(1)
}
SWIFT

swift "$WORK/flatten.swift" "$SRC" "$DEST"

echo "installed $DEST"
sips -g pixelWidth -g pixelHeight -g hasAlpha "$DEST"
