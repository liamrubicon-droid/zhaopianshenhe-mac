# 照片审核（macOS 原生版）

Windows 版「照片审核处理工具.exe」的 macOS 复刻，用 SwiftUI + 苹果 Vision 人脸检测实现，
界面走苹果简约风格。算法参数从原 exe 二进制内嵌配置逆向提取。

## 快速获取（二选一）

**方式 A · 下载即用**：从 Releases 下载 `照片审核-Mac通用版.zip`（同时支持 Intel 和
Apple Silicon），解压后双击 `照片审核.app`。若系统提示“无法验证开发者”，右键点击 →「打开」即可。

**方式 B · 一句话交给 AI 助手**（豆包 / DeepSeek / WorkBuddy / Claude Code 等任何能跑终端的 agent），
复制下面整段发给它即可：

```
xcode-select --install   # 首次需安装 Xcode 命令行工具
git clone https://github.com/liamrubicon-droid/zhaopianshenhe-mac.git && cd zhaopianshenhe-mac && bash build.sh && open 照片审核.app
```

## 成品

双击运行 **`照片审核.app`**（已 ad-hoc 签名，通用二进制）。若系统提示“无法验证开发者”，
右键点击 →「打开」即可。

应用图标为手绘原创（纯 Core Graphics 绘制），不含任何第三方素材。

用法与原件一致：
1. 点「打开照片文件」选一张 JPG/JPEG 证件照；
2. 通过后点「保存照片文件」，默认文件名 `报名照片.jpg`；
3. 用保存的照片到报名网站上传。

## 从原 exe 逆向出的参数（`Sources/PhotoReview/PhotoProcessor.swift` 内 `PhotoConfig`）

| 参数 | 值 | 来源 |
| --- | --- | --- |
| 输出尺寸 dst_width × dst_height | 295 × 413 | exe 内嵌 photo.ini 默认值 |
| 源图最小 min_width × min_height | 215 × 300 | exe 内嵌 |
| 源图最小文件大小 | 30 K | 帮助文档 |
| 源图格式 | JPG/JPEG（*.jpg;*.jpeg;*.jpe;*.jfif） | exe 文件过滤器 |
| 背景 | 红 / 白 / 蓝 | 帮助文档 |
| 人脸模型 | haarcascade_frontalface_alt2.xml | exe 内嵌 |
| 输出文件名 | 报名照片.jpg，约 10K | exe 内嵌 + 帮助文档 |

## 命令行模式（可选）

`PhotoReview` 可执行文件带参数时走命令行，便于批处理/测试：

```bash
.build/release/PhotoReview 原照片.jpg [输出路径]
```

## 重新构建

```bash
bash build.sh
```

依赖：Xcode 命令行工具（`swift` 6.x）。

## 与原件的差异（如实说明）

1. **人脸检测**：原件用 OpenCV 1.0 的 Haar 级联（`haarcascade_frontalface_alt2.xml`），
   本版用苹果原生 Vision 人脸检测（无第三方依赖、更稳）。二者检测结果的人脸框略有差异，
   因此裁剪位置与原件并非逐像素一致，但输出规格（295×413、~10K）完全一致。
2. **裁剪比例**：原件人脸→裁框的精确公式未能从二进制完整还原，本版按标准一寸照
   头部约占 2/3 的通用规范重建。
3. 报名网站实际校验的是**处理后的 295×413 文件**，本版输出已对齐该规格；
   是否通过以报名网站最终校验为准。
