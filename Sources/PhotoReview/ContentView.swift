import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var originalImage: CGImage?
    @State private var result: ProcessedResult?
    @State private var statusText = "请打开一张 JPG 证件照进行审核"
    @State private var passed = false
    @State private var sourceSizeKB: Double?

    var body: some View {
        VStack(spacing: 22) {
            header
            previewRow
            statusRow
            buttonsRow
        }
        .padding(28)
        .frame(width: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 头部

    private var header: some View {
        VStack(spacing: 4) {
            Text("照片审核")
                .font(.system(size: 26, weight: .bold, design: .default))
            Text("公务员 / 报名照片审核处理工具")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 预览区

    private var previewRow: some View {
        HStack(spacing: 16) {
            previewCard(title: "原照片", image: originalImage)
            previewCard(title: "处理后照片", image: result?.image)
        }
    }

    private func previewCard(title: String, image: CGImage?) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                if let img = image {
                    Image(decorative: img, scale: 1.0)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(6)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .frame(width: 210, height: 290)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 状态区

    private var statusRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusColor)
                    .multilineTextAlignment(.center)
            }

            if let r = result {
                HStack(spacing: 8) {
                    chip("\(r.width) × \(r.height)")
                    chip(String(format: "%.1f K", r.sizeKB))
                    chip("JPG")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statusIcon: String {
        if passed { return "checkmark.circle.fill" }
        if statusText.contains("审核不通过") { return "xmark.circle.fill" }
        return "info.circle"
    }

    private var statusColor: Color {
        if passed { return .green }
        if statusText.contains("审核不通过") { return .red }
        return .secondary
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
            .foregroundColor(.secondary)
    }

    // MARK: - 按钮区

    private var buttonsRow: some View {
        HStack(spacing: 12) {
            Button(action: openPhoto) {
                Label("打开照片文件", systemImage: "folder")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: savePhoto) {
                Label("保存照片文件", systemImage: "square.and.arrow.down")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!passed)
        }
    }

    // MARK: - 打开照片

    private func openPhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .bmp, .tiff, .heic, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择要审核的证件照（JPG/JPEG）"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            sourceSizeKB = Double(data.count) / 1024.0

            // 先解码原图用于预览
            if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
               let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                originalImage = img
            }

            let processed = try PhotoProcessor.process(at: url)
            result = processed
            passed = true
            statusText = "审核通过，可以保存照片"
        } catch {
            result = nil
            passed = false
            statusText = "审核不通过：" + (error.localizedDescription)
        }
    }

    // MARK: - 保存照片

    private func savePhoto() {
        guard let r = result else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "报名照片.jpg"
        panel.allowedContentTypes = [.jpeg]
        panel.canCreateDirectories = true
        panel.message = "保存审核通过的照片（默认文件名：报名照片.jpg）"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try r.data.write(to: url)
            statusText = "已保存：" + (url.lastPathComponent)
        } catch {
            statusText = "保存失败：" + error.localizedDescription
        }
    }
}
