#!/bin/bash
# 构建「照片审核」原生 macOS 应用（自动识别架构；Apple Silicon 上合成 arm64+x86_64 通用二进制）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="照片审核"
BIN_NAME="PhotoReview"
APP_DIR="$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"

HOST_ARCH="$(uname -m)"

# 决定要编译哪些架构：本机必编；Apple Silicon 再补一个 x86_64 做成通用包
ARCHS=("$HOST_ARCH")
if [ "$HOST_ARCH" = "arm64" ]; then
    ARCHS+=("x86_64")
fi

echo "==> 编译架构：${ARCHS[*]}"
for a in "${ARCHS[@]}"; do
    echo "    [swift build -c release --arch $a]"
    swift build -c release --arch "$a"
done

echo "==> 组装 $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

if [ "${#ARCHS[@]}" -gt 1 ]; then
    echo "==> 合成通用二进制 (lipo)"
    lipo -create \
        ".build/arm64-apple-macosx/release/$BIN_NAME" \
        ".build/x86_64-apple-macosx/release/$BIN_NAME" \
        -output "$CONTENTS/MacOS/$BIN_NAME"
else
    cp ".build/${HOST_ARCH}-apple-macosx/release/$BIN_NAME" "$CONTENTS/MacOS/$BIN_NAME"
fi

cp icon/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>local.zhaopianshenhe.photoreview</string>
    <key>CFBundleExecutable</key><string>$BIN_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

echo "==> 签名 (ad-hoc)"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "(签名跳过)"

echo "完成：$(pwd)/$APP_DIR"
