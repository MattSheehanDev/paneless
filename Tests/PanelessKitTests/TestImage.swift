import CoreGraphics
import Foundation

struct RGBA: Equatable, CustomStringConvertible {
    var r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255

    var description: String { "rgba(\(r), \(g), \(b), \(a))" }

    func isClose(to other: RGBA, tolerance: Int = 8) -> Bool {
        abs(Int(r) - Int(other.r)) <= tolerance
            && abs(Int(g) - Int(other.g)) <= tolerance
            && abs(Int(b) - Int(other.b)) <= tolerance
            && abs(Int(a) - Int(other.a)) <= tolerance
    }
}

/// sRGB test images addressed with a top-left origin, matching the app's flipped coordinates.
enum TestImage {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    static func make(width: Int, height: Int, pixel: (_ x: Int, _ y: Int) -> RGBA) -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let p = pixel(x, y), i = (y * width + x) * 4
                bytes[i] = p.r; bytes[i + 1] = p.g; bytes[i + 2] = p.b; bytes[i + 3] = p.a
            }
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: sRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(bytes) as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    static func pixel(_ image: CGImage, x: Int, y: Int) -> RGBA {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let i = (y * image.width + x) * 4
        return RGBA(r: bytes[i], g: bytes[i + 1], b: bytes[i + 2], a: bytes[i + 3])
    }
}
