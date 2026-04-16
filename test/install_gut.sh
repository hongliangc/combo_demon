#!/bin/bash
# ============================================================
# GUT (Godot Unit Test) 安装脚本
# 用法: bash test/install_gut.sh [--force]
# ============================================================

GUT_VERSION="9.6.0"
GUT_URL="https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VERSION}.zip"
DEST="addons/gut"
TMP_ZIP="/tmp/gut_${GUT_VERSION}.zip"
TMP_DIR="/tmp/gut_${GUT_VERSION}_extract"

# --force 参数：强制重装
if [ "$1" = "--force" ]; then
    echo "Force reinstall: removing existing $DEST"
    rm -rf "$DEST"
fi

# 检查是否已完整安装（需要有 gui/ 子目录）
if [ -d "$DEST/gui" ] && [ -d "$DEST/cli" ]; then
    echo "GUT v${GUT_VERSION} already installed at $DEST"
    exit 0
fi

# 清理不完整的安装
[ -d "$DEST" ] && rm -rf "$DEST"

echo "Downloading GUT v${GUT_VERSION}..."
curl -L "$GUT_URL" -o "$TMP_ZIP"

if [ ! -f "$TMP_ZIP" ]; then
    echo "ERROR: Download failed"
    exit 1
fi

echo "Extracting (full directory tree)..."
rm -rf "$TMP_DIR"
mkdir -p addons
unzip -o "$TMP_ZIP" "Gut-${GUT_VERSION}/addons/gut/*" -d "$TMP_DIR"
cp -r "$TMP_DIR/Gut-${GUT_VERSION}/addons/gut" addons/

echo "Cleaning up..."
rm -rf "$TMP_ZIP" "$TMP_DIR"

# 验证安装
if [ -d "$DEST/gui" ] && [ -d "$DEST/cli" ]; then
    echo ""
    echo "GUT v${GUT_VERSION} installed successfully to $DEST"
    echo "Subdirectories: $(ls -d $DEST/*/ 2>/dev/null | xargs -I{} basename {} | tr '\n' ' ')"
    echo ""
    echo "Next steps:"
    echo "  1. Open project in Godot editor (imports resources)"
    echo "  2. Enable plugin: Project → Project Settings → Plugins → GUT"
    echo "  3. Run tests:  bash test/run_tests.sh"
else
    echo "ERROR: Installation incomplete — missing gui/ or cli/ subdirectories"
    exit 1
fi
