#!/bin/bash
# Apple 字体和 Emoji 完整安装脚本

echo "=== 安装 Apple 字体系列 ==="

# 1. 安装Apple emoji字体
echo "安装 Apple Color Emoji..."
yay -S --needed ttf-apple-emoji

# 2. 安装Apple中文字体 (PingFang)
echo "安装 Apple PingFang 中文字体..."
yay -S --needed ttf-pingfang-git

# 3. 安装Apple英文字体系列 (San Francisco等)
echo "安装 Apple 英文字体系列..."
yay -S --needed apple-fonts

# 3. 在现有配置中添加Apple emoji支持
echo "添加Apple emoji字体配置..."
# 检查是否已经有emoji配置
if ! grep -q "emoji" ~/.config/fontconfig 2>/dev/null; then
    # 在</fontconfig>前添加emoji配置
    sed -i '/<\/fontconfig>/i \
\
        <!-- Apple Emoji Font -->\
        <match target="pattern">\
                <test qual="any" name="family">\
                        <string>emoji</string>\
                </test>\
                <edit name="family" mode="prepend" binding="strong">\
                        <string>Apple Color Emoji</string>\
                </edit>\
        </match>\
\
        <alias>\
                <family>Apple Color Emoji</family>\
                <default>\
                        <family>emoji</family>\
                </default>\
        </alias>' ~/.config/fontconfig
fi

# 4. 刷新字体缓存
echo "刷新字体缓存..."
fc-cache -fv

echo "✅ Apple风格emoji字体安装完成！"
echo "🍎 现在你的系统将使用Apple风格的emoji"
echo "🔄 可能需要重启浏览器和应用程序来看到效果"
echo "🔍 可以运行 'fc-list | grep -i emoji' 查看emoji字体"
