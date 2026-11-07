---
name: photo-review
description: Use when reviewing or processing a Chinese civil-service / exam registration ID photo (报名照片 / 证件照) on macOS — validate JPG/JPEG format, file size, pixel dimensions, red/white/blue background and face detection, then produce a 295×413 ~10K JPG named 报名照片.jpg.
---

# 照片审核（macOS）

把一张报名证件照审核并处理成报名网站要求的规格：**295×413、约 10K、JPG、红/白/蓝背景、正面人脸**。

## 首次安装

本机还没装好工具时，先执行（需 Xcode 命令行工具：`xcode-select --install`）：

```bash
git clone https://github.com/liamrubicon-droid/zhaopianshenhe-mac.git ~/.zhaopianshenhe-mac && cd ~/.zhaopianshenhe-mac && bash build.sh
```

编译产物：GUI `照片审核.app`，其可执行文件位于 `照片审核.app/Contents/MacOS/PhotoReview`。

## 审核一张照片（命令行，最常用）

```bash
"$HOME/.zhaopianshenhe-mac/照片审核.app/Contents/MacOS/PhotoReview" 输入.jpg 输出.jpg
```

- 通过 → 打印 `审核通过：输出.jpg 295x413 xx.xK`，退出码 0
- 不通过 → 打印 `审核不通过：<原因>`，退出码 1

## GUI

```bash
open "$HOME/.zhaopianshenhe-mac/照片审核.app"
```

打开照片 → 通过后点「保存照片文件」，默认文件名 `报名照片.jpg`。

## 审核规则（不通过的原因）

| 检查项 | 要求 |
| --- | --- |
| 格式 | JPG/JPEG（*.jpg / *.jpeg / *.jpe / *.jfif） |
| 文件大小 | > 30K |
| 像素 | ≥ 215×300 |
| 背景 | 红 / 白 / 蓝 |
| 人脸 | 能检测到正面人脸 |
