#!/bin/bash

# FileTransfer 自动构建脚本
# 用法: ./build_all.sh [apk|exe|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}[✓] $1${NC}"; }
print_error() { echo -e "${RED}[✗] $1${NC}"; }
print_info() { echo -e "${YELLOW}[i] $1${NC}"; }

# 创建输出目录
OUTPUT_DIR="build_output"
mkdir -p "$OUTPUT_DIR"

build_apk() {
    print_info "开始构建 Android APK..."

    # 清理旧构建
    flutter clean > /dev/null 2>&1
    flutter pub get > /dev/null 2>&1

    # 构建 APK
    flutter build apk --release

    if [ $? -eq 0 ]; then
        APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
        if [ -f "$APK_PATH" ]; then
            cp "$APK_PATH" "$OUTPUT_DIR/file_transfer.apk"
            APK_SIZE=$(du -h "$OUTPUT_DIR/file_transfer.apk" | cut -f1)
            print_success "APK 构建成功: $OUTPUT_DIR/file_transfer.apk ($APK_SIZE)"
        else
            print_error "APK 文件未找到"
            return 1
        fi
    else
        print_error "APK 构建失败"
        return 1
    fi
}

build_exe() {
    print_info "开始构建 Windows EXE..."

    # 清理旧构建
    flutter clean > /dev/null 2>&1
    flutter pub get > /dev/null 2>&1

    # 构建 Windows EXE
    flutter build windows --release

    if [ $? -eq 0 ]; then
        EXE_DIR="build/windows/x64/runner/Release"
        if [ -d "$EXE_DIR" ]; then
            # 复制整个 Release 目录
            cp -r "$EXE_DIR" "$OUTPUT_DIR/windows"
            EXE_SIZE=$(du -sh "$OUTPUT_DIR/windows" | cut -f1)
            print_success "EXE 构建成功: $OUTPUT_DIR/windows/ ($EXE_SIZE)"
            print_info "可执行文件: $OUTPUT_DIR/windows/file_transfer.exe"
        else
            print_error "Windows 构建目录未找到"
            return 1
        fi
    else
        print_error "EXE 构建失败"
        return 1
    fi
}

# 主逻辑
TARGET="${1:-all}"

case "$TARGET" in
    apk)
        build_apk
        ;;
    exe)
        build_exe
        ;;
    all)
        build_apk
        echo ""
        build_exe
        ;;
    *)
        print_error "未知目标: $TARGET"
        echo "用法: $0 [apk|exe|all]"
        exit 1
        ;;
esac

echo ""
print_info "构建完成！输出目录: $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR/"
