import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 让 SPM 可执行文件以正式 App 身份运行（能出现在 Dock、能弹文件面板）
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

struct PhotoReviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("照片审核") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

// 自定义入口：带参数走命令行处理（便于测试/批处理），否则启动 GUI
@main
struct Main {
    static func main() {
        let args = CommandLine.arguments
        if args.count > 1 {
            let src = URL(fileURLWithPath: args[1])
            do {
                let r = try PhotoProcessor.process(at: src)
                let dst = args.count > 2 ? URL(fileURLWithPath: args[2]) : URL(fileURLWithPath: "报名照片.jpg")
                try r.data.write(to: dst)
                print("审核通过：\(dst.path) \(r.width)x\(r.height) \(String(format: "%.1f", r.sizeKB))K")
                exit(0)
            } catch {
                FileHandle.standardError.write("审核不通过：\(error.localizedDescription)\n".data(using: .utf8)!)
                exit(1)
            }
        }
        PhotoReviewApp.main()
    }
}
