#!/bin/bash

# Pink Dark Theme 安装脚本 - GitHub 版本
# 用于从 GitHub 仓库本地安装 VS Code 主题

THEME_NAME="lemuen-darksakura-darkpink-theme"
VSCODE_EXTENSIONS_DIR="$HOME/.vscode/extensions"
THEME_DIR="$VSCODE_EXTENSIONS_DIR/$THEME_NAME"

echo "� Lemuen Darksakura Darkpink Theme 安装程序 (GitHub 版本)"
echo "==========================================="

# 检查是否安装了 VS Code
if ! command -v code &> /dev/null; then
    echo "❌ 未检测到 VS Code，请先安装 Visual Studio Code"
    echo "💡 下载地址: https://code.visualstudio.com/"
    exit 1
fi

# 创建扩展目录
echo "📁 创建主题目录..."
mkdir -p "$THEME_DIR/themes"

# 检查当前目录是否包含主题文件
if [ ! -f "lemuen-darksakura-darkpink-theme.json" ] || [ ! -f "package.json" ]; then
    echo "❌ 在当前目录中未找到主题文件"
    echo "💡 请确保在 GitHub 版本目录中运行此脚本"
    exit 1
fi

# 复制主题文件
echo "📋 复制主题文件..."
cp "lemuen-darksakura-darkpink-theme.json" "$THEME_DIR/themes/"
cp "package.json" "$THEME_DIR/"

# 复制文档文件
cp "README.md" "$THEME_DIR/" 2>/dev/null || true
cp "LICENSE" "$THEME_DIR/" 2>/dev/null || true
cp "CHANGELOG.md" "$THEME_DIR/" 2>/dev/null || true

echo "✅ 主题安装完成！"
echo ""
echo "📌 下一步操作："
echo "1. 重启 VS Code"
echo "2. 按 Ctrl+Shift+P (或 Cmd+Shift+P) 打开命令面板"
echo "3. 输入 'Color Theme' 并选择"
echo "4. 选择 'Lemuen Darksakura Darkpink Theme'"
echo ""
echo "🖼️  如需自定义左上角图标，请参考 README.md 中的说明"
echo "🎉 享受你的新主题！"
