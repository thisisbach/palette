import AppKit
let destination = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 210, yRadius: 210)
NSColor(calibratedWhite: 0.95, alpha: 1).setFill(); tile.fill()
let colors: [NSColor] = [NSColor(srgbRed: 0.98, green: 0.40, blue: 0.36, alpha: 1), NSColor(srgbRed: 0.99, green: 0.69, blue: 0.29, alpha: 1), NSColor(srgbRed: 0.32, green: 0.65, blue: 0.62, alpha: 1), NSColor(srgbRed: 0.34, green: 0.37, blue: 0.76, alpha: 1)]
for (i, color) in colors.enumerated() {
 NSGraphicsContext.saveGraphicsState()
 let transform = NSAffineTransform()
 transform.translateX(by: 512, yBy: 285)
 transform.rotate(byDegrees: CGFloat(24 - i * 16))
 transform.concat()
 let rect = NSRect(x: -100, y: -75, width: 200, height: 550)
 let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.14); shadow.shadowBlurRadius = 20; shadow.shadowOffset = NSSize(width: 0, height: -7); shadow.set()
 color.setFill(); NSBezierPath(roundedRect: rect, xRadius: 40, yRadius: 40).fill()
 NSGraphicsContext.restoreGraphicsState()
}
NSColor.white.withAlphaComponent(0.85).setFill()
NSBezierPath(ovalIn: NSRect(x: 493, y: 267, width: 38, height: 38)).fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
