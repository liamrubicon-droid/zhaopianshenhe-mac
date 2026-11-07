import Foundation
import CoreGraphics
import ImageIO
import Vision

// MARK: - 审核错误（文案对应原工具的“审核不通过”提示）

enum ReviewError: LocalizedError {
    case notJPEG
    case tooSmallFile
    case tooSmallPixels(width: Int, height: Int)
    case badBackground
    case noFace

    var errorDescription: String? {
        switch self {
        case .notJPEG:
            return "照片必须是 JPG 或 JPEG 格式"
        case .tooSmallFile:
            return "照片文件大小必须大于 30K"
        case .tooSmallPixels(let w, let h):
            return "照片像素必须不小于 215×300（当前 \(w)×\(h)）"
        case .badBackground:
            return "照片背景必须是红色、白色或蓝色"
        case .noFace:
            return "未检测到人脸，请使用正面免冠证件照"
        }
    }
}

// MARK: - 背景检测结果

enum BackgroundColor {
    case red, white, blue, unknown
}

// MARK: - 处理结果

struct ProcessedResult {
    let image: CGImage
    let data: Data          // JPEG 数据
    let width: Int
    let height: Int
    let sizeKB: Double
}

// MARK: - 逆向自原 exe 的参数（见 exe 内嵌 photo.ini 默认值 + 帮助文档）

enum PhotoConfig {
    static let dstWidth = 295
    static let dstHeight = 413
    static let minWidth = 215
    static let minHeight = 300
    static let minSourceBytes = 30 * 1024
    static let targetMaxBytes = 11 * 1024   // 输出约 10K
    static let jpegExtensions = ["jpg", "jpeg", "jpe", "jfif"]
}

enum PhotoProcessor {

    // MARK: 主入口：审核并处理照片

    static func process(at url: URL) throws -> ProcessedResult {
        // 1. 格式：JPG/JPEG
        let ext = url.pathExtension.lowercased()
        guard PhotoConfig.jpegExtensions.contains(ext) else {
            throw ReviewError.notJPEG
        }

        // 2. 文件大小 > 30K
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attrs[.size] as? Int, size > PhotoConfig.minSourceBytes else {
            throw ReviewError.tooSmallFile
        }

        // 3. 解码
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw ReviewError.notJPEG
        }

        let w = cgImage.width
        let h = cgImage.height

        // 4. 像素：宽 ≥ 215 且 高 ≥ 300
        guard w >= PhotoConfig.minWidth && h >= PhotoConfig.minHeight else {
            throw ReviewError.tooSmallPixels(width: w, height: h)
        }

        // 5. 背景：红 / 白 / 蓝
        guard let rgb = backgroundColor(of: cgImage) else {
            throw ReviewError.badBackground
        }
        let bg = classify(r: rgb.r, g: rgb.g, b: rgb.b)
        guard bg != .unknown else {
            throw ReviewError.badBackground
        }

        // 6. 人脸检测（苹果 Vision，原生、无第三方依赖）
        guard let face = largestFace(in: cgImage) else {
            throw ReviewError.noFace
        }

        // 7. 按证件照比例裁剪
        let cropRect = cropRegion(face: face, imageW: w, imageH: h)
        guard let cropped = cgImage.cropping(to: cropRect) else {
            throw ReviewError.noFace
        }

        // 8. 缩放到 295×413
        guard let resized = resize(cropped, PhotoConfig.dstWidth, PhotoConfig.dstHeight) else {
            throw ReviewError.noFace
        }

        // 9. JPEG 压缩到约 10K
        let data = encodeJPEG(resized, targetMax: PhotoConfig.targetMaxBytes)

        return ProcessedResult(
            image: resized,
            data: data,
            width: PhotoConfig.dstWidth,
            height: PhotoConfig.dstHeight,
            sizeKB: Double(data.count) / 1024.0
        )
    }

    // MARK: - 背景取样：取四角 + 四边中点，求平均 RGB

    private static func backgroundColor(of image: CGImage) -> (r: Double, g: Double, b: Double)? {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }

        var px = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &px,
                                  width: w,
                                  height: h,
                                  bitsPerComponent: 8,
                                  bytesPerRow: w * 4,
                                  space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        let patch = 8
        var rSum = 0, gSum = 0, bSum = 0, n = 0
        func add(_ x: Int, _ y: Int) {
            guard x >= 0, x < w, y >= 0, y < h else { return }
            let i = (y * w + x) * 4
            rSum += Int(px[i]); gSum += Int(px[i + 1]); bSum += Int(px[i + 2]); n += 1
        }
        for dy in 0..<patch {
            for dx in 0..<patch {
                add(dx, dy)                 // 左上
                add(w - 1 - dx, dy)         // 右上
                add(dx, h - 1 - dy)         // 左下
                add(w - 1 - dx, h - 1 - dy) // 右下
            }
        }
        for k in 0..<patch {
            add(w / 2 - patch / 2 + k, 0)     // 上边中点
            add(w / 2 - patch / 2 + k, h - 1) // 下边中点
            add(0, h / 2 - patch / 2 + k)     // 左边中点
            add(w - 1, h / 2 - patch / 2 + k) // 右边中点
        }
        guard n > 0 else { return nil }
        return (Double(rSum) / Double(n), Double(gSum) / Double(n), Double(bSum) / Double(n))
    }

    // MARK: - RGB → 背景分类（红/白/蓝）

    private static func classify(r: Double, g: Double, b: Double) -> BackgroundColor {
        let rn = r / 255.0, gn = g / 255.0, bn = b / 255.0
        let maxV = max(rn, gn, bn), minV = min(rn, gn, bn)
        let delta = maxV - minV

        // 饱和度 S ∈ [0,255]，明度 V ∈ [0,255]，色相 H ∈ [0,360]
        let v = maxV * 255.0
        var s: Double = 0
        if maxV > 0 { s = delta / maxV * 255.0 }
        var h: Double = 0
        if delta > 0 {
            if maxV == rn { h = 60.0 * ((gn - bn) / delta).truncatingRemainder(dividingBy: 6.0) }
            else if maxV == gn { h = 60.0 * ((bn - rn) / delta + 2.0) }
            else { h = 60.0 * ((rn - gn) / delta + 4.0) }
            if h < 0 { h += 360.0 }
        }

        if s < 40 && v > 180 { return .white }
        if (h < 20 || h > 340) && s >= 40 { return .red }
        if h >= 180 && h <= 260 && s >= 40 { return .blue }
        return .unknown
    }

    // MARK: - 人脸检测（取最大人脸）

    private static func largestFace(in image: CGImage) -> (fx: Double, fy: Double, fw: Double, fh: Double)? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let faces = request.results ?? []
        guard let largest = faces.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
            return nil
        }
        let b = largest.boundingBox
        let W = Double(image.width), H = Double(image.height)
        let fw = b.width * W
        let fh = b.height * H
        let fx = b.origin.x * W
        let fy = (1 - b.origin.y - b.height) * H   // Vision 原点在左下，转成左上
        return (fx, fy, fw, fh)
    }

    // MARK: - 裁剪：人脸 → 证件照裁框（头部约占 2/3，宽高比 295:413）

    private static func cropRegion(face: (fx: Double, fy: Double, fw: Double, fh: Double),
                                   imageW: Int, imageH: Int) -> CGRect {
        let W = Double(imageW), H = Double(imageH)
        let fx = face.fx, fy = face.fy, fw = face.fw, fh = face.fh

        // 头高 ≈ 脸高 × 1.5（脸框大致为下巴→眉骨，向上补头发）
        let headH = fh * 1.5
        let cropH = headH / 0.66
        let cropW = cropH * Double(PhotoConfig.dstWidth) / Double(PhotoConfig.dstHeight)

        // 人脸占比异常（太大/太小）→ 回退为居中按比例裁剪
        if cropW > W * 1.2 || cropH > H * 1.2 || headH > H * 0.9 {
            var ch = H
            var cw = ch * Double(PhotoConfig.dstWidth) / Double(PhotoConfig.dstHeight)
            if cw > W { cw = W; ch = cw * Double(PhotoConfig.dstHeight) / Double(PhotoConfig.dstWidth) }
            return CGRect(x: (W - cw) / 2, y: (H - ch) / 2, width: cw, height: ch)
        }

        var cw = cropW, ch = cropH
        // 若超出图像，等比收缩
        if cw > W { cw = W; ch = cw * Double(PhotoConfig.dstHeight) / Double(PhotoConfig.dstWidth) }
        if ch > H { ch = H; cw = ch * Double(PhotoConfig.dstWidth) / Double(PhotoConfig.dstHeight) }

        var left = fx + fw / 2 - cw / 2
        var top = fy - fh * 0.5

        // 收边，保证在图像内
        left = min(max(left, 0), W - cw)
        top = min(max(top, 0), H - ch)

        return CGRect(x: left, y: top, width: cw, height: ch)
    }

    // MARK: - 缩放到指定尺寸

    private static func resize(_ image: CGImage, _ width: Int, _ height: Int) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: width * 4,
                                  space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    // MARK: - JPEG 编码：二分压缩质量，压到约 10K

    private static func encodeJPEG(_ image: CGImage, targetMax: Int) -> Data {
        func encode(quality: Double) -> Data? {
            let data = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
                return nil
            }
            let opts = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
            CGImageDestinationAddImage(dest, image, opts)
            guard CGImageDestinationFinalize(dest) else { return nil }
            return data as Data
        }

        // ImageIO 压缩质量取值范围是 0.0~1.0
        var lo = 0.05, hi = 0.95
        var best = encode(quality: 0.95) ?? Data()
        for _ in 0..<12 {
            let q = (lo + hi) / 2
            guard let buf = encode(quality: q), !buf.isEmpty else { break }
            if buf.count > targetMax {
                hi = q
            } else {
                best = buf
                lo = q
            }
        }
        return best
    }
}
