import AppKit

let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: size * 4,
                          space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }

let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ns

// 1. 圆角方框 + 渐变背景
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let bg = NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200)
let gradient = NSGradient(starting: NSColor(red: 0.22, green: 0.55, blue: 0.99, alpha: 1),
                          ending: NSColor(red: 0.34, green: 0.34, blue: 0.90, alpha: 1))!
gradient.draw(in: bg, angle: -90)

// 2. 白色人像剪影（纯手绘圆形，无任何第三方素材）
// flipped:false 坐标系 y 越大越靠上：头在上、肩在下
NSColor.white.setFill()
// 肩部（下，大圆）
NSBezierPath(ovalIn: NSRect(x: 512 - 270, y: 320 - 270, width: 540, height: 540)).fill()
// 头部（上，小圆）
NSBezierPath(ovalIn: NSRect(x: 512 - 150, y: 660 - 150, width: 300, height: 300)).fill()

NSGraphicsContext.restoreGraphicsState()

guard let img = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: img)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "icon/icon1024.png"))
print("icon/icon1024.png written")
