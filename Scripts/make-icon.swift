// Рисует иконку приложения и раскладывает её по размерам в AppIcon.appiconset.
// Запуск из корня проекта: swift Scripts/make-icon.swift
//
// Всё нарисовано строго внутри «скруглённого квадрата» по сетке Apple (824 pt на холсте 1024):
// если пиксели выходят за его края, macOS 26+ кладёт иконку в серую подложку.

import AppKit
import SwiftUI

let canvas: CGFloat = 1024
let tile: CGFloat = 824
let tileRadius: CGFloat = 185

let mint = Color(red: 0.30, green: 0.94, blue: 0.80)
let teal = Color(red: 0.13, green: 0.70, blue: 0.86)
let blue = Color(red: 0.25, green: 0.38, blue: 0.98)
let violet = Color(red: 0.45, green: 0.27, blue: 0.92)

struct Sparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * 0.16
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        return p
    }
}

struct Icon: View {
    var body: some View {
        let squircle = RoundedRectangle(cornerRadius: tileRadius, style: .continuous)
        let keyShape = RoundedRectangle(cornerRadius: 96, style: .continuous)

        ZStack {
            // Фон
            squircle.fill(LinearGradient(colors: [mint, teal, blue, violet],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            squircle.fill(RadialGradient(colors: [.white.opacity(0.45), .clear],
                                         center: UnitPoint(x: 0.2, y: 0.12), startRadius: 0, endRadius: 520))

            // Тень клавиши
            keyShape
                .fill(Color(red: 0.05, green: 0.12, blue: 0.35).opacity(0.35))
                .frame(width: 440, height: 440)
                .blur(radius: 30)
                .offset(y: 38)

            // Стеклянная клавиша
            ZStack {
                keyShape.fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.16)],
                                             startPoint: .top, endPoint: .bottom))
                // След «протирки» — диагональный блик
                keyShape
                    .fill(LinearGradient(stops: [
                        .init(color: .clear, location: 0.28),
                        .init(color: .white.opacity(0.55), location: 0.42),
                        .init(color: .white.opacity(0.1), location: 0.52),
                        .init(color: .clear, location: 0.6),
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                keyShape.strokeBorder(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.25)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 7)
                Sparkle()
                    .fill(.white)
                    .frame(width: 210, height: 210)
                    .shadow(color: Color(red: 0.1, green: 0.3, blue: 0.7).opacity(0.35), radius: 16, y: 8)
            }
            .frame(width: 440, height: 440)

            // Искорки
            Sparkle().fill(.white).frame(width: 92, height: 92).offset(x: 250, y: -250)
            Sparkle().fill(.white.opacity(0.85)).frame(width: 52, height: 52).offset(x: 312, y: -150)
            Sparkle().fill(.white.opacity(0.7)).frame(width: 44, height: 44).offset(x: -270, y: 268)
        }
        .frame(width: tile, height: tile)
        .clipShape(squircle)
        .frame(width: canvas, height: canvas)
    }
}

let output = URL(fileURLWithPath: "CleanKeyboard/Resources/Assets.xcassets/AppIcon.appiconset")

let cgImage = MainActor.assumeIsolated { () -> CGImage in
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = 1
    guard let image = renderer.cgImage else { fatalError("Не удалось отрисовать иконку") }
    return image
}
let master = NSBitmapImageRep(cgImage: cgImage)

func write(size: Int, name: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    master.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}

var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        write(size: base * scale, name: name)
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("Contents.json"))
print("Иконка записана в \(output.path)")
