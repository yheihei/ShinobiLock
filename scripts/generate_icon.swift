import AppKit

// Original vector artwork, rendered at the App Store's required icon size.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSColor(srgbRed: 0.13, green: 0.23, blue: 0.20, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let paper = NSColor(srgbRed: 0.96, green: 0.95, blue: 0.90, alpha: 1)
paper.setStroke()
let shackle = NSBezierPath()
shackle.move(to: NSPoint(x: 352, y: 515))
shackle.line(to: NSPoint(x: 352, y: 635))
shackle.curve(to: NSPoint(x: 672, y: 635), controlPoint1: NSPoint(x: 352, y: 850), controlPoint2: NSPoint(x: 672, y: 850))
shackle.line(to: NSPoint(x: 672, y: 515))
shackle.lineWidth = 64
shackle.lineCapStyle = .round
shackle.stroke()
paper.setFill()
NSBezierPath(roundedRect: NSRect(x: 259, y: 229, width: 506, height: 344), xRadius: 80, yRadius: 80).fill()
NSColor(srgbRed: 0.13, green: 0.23, blue: 0.20, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 476, y: 390, width: 72, height: 72)).fill()
NSBezierPath(roundedRect: NSRect(x: 492, y: 334, width: 40, height: 102), xRadius: 20, yRadius: 20).fill()
NSColor(srgbRed: 0.78, green: 0.88, blue: 0.56, alpha: 1).setFill()
let leaf = NSBezierPath()
leaf.move(to: NSPoint(x: 705, y: 690))
leaf.curve(to: NSPoint(x: 843, y: 836), controlPoint1: NSPoint(x: 697, y: 808), controlPoint2: NSPoint(x: 805, y: 817))
leaf.curve(to: NSPoint(x: 705, y: 690), controlPoint1: NSPoint(x: 830, y: 732), controlPoint2: NSPoint(x: 768, y: 690))
leaf.fill()
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("AppIcon.png"))
try """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
""".write(to: output.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
