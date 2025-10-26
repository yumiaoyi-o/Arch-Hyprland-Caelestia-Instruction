#!/bin/bash
# Fcitx5 中文输入法安装脚本

echo "=== 安装 Fcitx5 中文输入法 ==="

# 1. 安装 fcitx5 主程序和中文输入法
echo "安装 fcitx5 核心包..."
sudo pacman -S --needed fcitx5-im fcitx5-chinese-addons fcitx5-gtk fcitx5-qt

# 2. 安装词库
echo "安装中文词库..."
sudo pacman -S --needed fcitx5-pinyin-moegirl fcitx5-pinyin-zhwiki

# 3. 设置 fcitx5 自启动
echo "设置自启动..."
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/fcitx5.desktop << 'EOF'
[Desktop Entry]
Name=Fcitx5
GenericName=Input Method
Comment=Start Input Method
Exec=fcitx5
Icon=fcitx
Terminal=false
Type=Application
Categories=System;Utility;
StartupNotify=false
X-GNOME-Autostart-Phase=Applications
X-GNOME-AutoRestart=false
X-GNOME-Autostart-Delay=0
X-KDE-autostart-after=panel
EOF

echo "✅ Fcitx5 安装完成！"
echo "🔄 请重启系统或重新登录以使环境变量生效"
echo "⚙️  启动后可以运行 'fcitx5-configtool' 进行详细配置"
echo "📝 默认切换快捷键: Ctrl+Space"
