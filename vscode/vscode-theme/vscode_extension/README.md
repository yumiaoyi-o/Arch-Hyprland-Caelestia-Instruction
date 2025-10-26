# Lemuen Darksakura Darkpink Theme

一个优雅的樱花粉色 VS Code 主题，专为提供舒适的编程体验而设计。

> 🎨 **设计灵感**: 主题配色灵感来源于明日方舟角色蕾缪安，以其优雅的黑粉配色为主调，营造温馨而专业的编码环境。

![Theme Preview](https://img.shields.io/badge/version-1.0.0-pink?style=flat-square)
![VS Code](https://img.shields.io/badge/VS%20Code-1.74%2B-blue?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

## ✨ 特性

- 🌸 **樱花粉色**：深灰色背景 (#1d1c20) 配樱花粉色高亮
- 🔥 **语法高亮**：针对多种编程语言优化的语法着色
- 👁️ **护眼设计**：柔和的对比度，减少眼部疲劳
- 🚀 **完整支持**：支持 Git 状态指示、错误高亮等
- 🎯 **无透明度**：纯色设计，界面清晰专业
- 🧹 **简洁边框**：无干扰的无边框设计

## 🎨 颜色方案

| 元素 | 颜色名称 | 十六进制代码 |
|------|----------|-------------|
| 背景色 | 深灰色 | `#1d1c20` |
| 主要粉色 | 樱花粉 | `#f7b7b5` |
| 强调黄色 | 奶油色 | `#fde4e0` |
| 警告红色 | 柔和红 | `#95474d` |
| 边框粉色 | 深粉色 | `#bc5e77` |
| 紫色强调 | 浅紫色 | `#ffd5e3` |

## 📦 安装

### 方法 1: VS Code 扩展市场 (推荐)
1. 打开 VS Code
2. 前往扩展面板 (`Ctrl+Shift+X` 或 `Cmd+Shift+X`)
3. 搜索 "Lemuen Darksakura Darkpink Theme"
4. 点击安装
5. 前往设置 → 颜色主题，选择 "Lemuen Darksakura Darkpink Theme"

### 方法 2: 从 GitHub 安装 (开发版本)
```bash
# 克隆仓库
git clone https://github.com/yumiaoyi-o/lemuen-darksakura-darkpink-theme.git
cd lemuen-darksakura-darkpink-theme/github

# 运行安装脚本
chmod +x install-theme.sh
./install-theme.sh
```

### 方法 3: 手动安装
1. 从 [GitHub Releases](https://github.com/yumiaoyi-o/lemuen-darksakura-darkpink-theme/releases) 下载
2. 复制文件到 VS Code 扩展目录：
   - **Windows**: `%USERPROFILE%\.vscode\extensions\lemuen-darksakura-darkpink-theme\`
   - **macOS**: `~/.vscode/extensions/lemuen-darksakura-darkpink-theme\`
   - **Linux**: `~/.vscode/extensions/lemuen-darksakura-darkpink-theme\`
3. 重启 VS Code
4. 选择主题：设置 → 颜色主题 → "Lemuen Darksakura Darkpink Theme"

## 🖼️ 自定义 VS Code 左上角图标

如果你想要将 VS Code 窗口左上角的图标替换为自定义图标：

### � 简单方法
找到 VS Code 安装目录中的 `code-icon.svg` 文件，用你自己的 SVG 图标替换即可。

**文件位置参考（Linux）**: `/opt/visual-studio-code/resources/app/out/media/code-icon.svg`

**参考图标**: 本项目包含 `LATERANO.svg` 作为示例

### ⚠️ 注意事项
- 替换系统文件需要管理员权限
- VS Code 更新后可能需要重新替换
- 建议先备份原始文件

## 🎨 个性化建议

**透明度优化**: 如果你使用支持透明度的终端或窗口管理器，建议将窗口透明度设置为 0.6-0.8，这样可以让主题的黑粉配色展现出更佳的视觉效果。

## 🛠️ 支持的语言

此主题为以下语言提供增强的语法高亮：

- **Web 开发**: HTML, CSS, JavaScript, TypeScript, React, Vue
- **后端开发**: Python, Java, C++, C#, Go, Rust
- **数据配置**: JSON, YAML, XML, Markdown
- **以及更多...**

## 🔧 自定义设置

你可以通过修改 VS Code 设置来进一步自定义主题。在 `settings.json` 中添加：

```json
{
  "workbench.colorCustomizations": {
    "[Lemuen Darksakura Darkpink Theme]": {
      "editor.background": "#your-custom-color"
    }
  }
}
```

##  项目版本

### VS Code 扩展版本
- **用途**: VS Code 扩展市场发布
- **包含**: 核心主题文件和基本文档
- **安装**: 直接在 VS Code 扩展市场搜索安装

### GitHub 开发版本
- **用途**: 开源开发和自定义功能
- **包含**: 完整源码、安装脚本、自定义图标功能
- **安装**: 克隆仓库后使用安装脚本

## 🤝 贡献

欢迎贡献！如果你有建议或发现问题：

1. 在 [GitHub](https://github.com/yumiaoyi-o/lemuen-darksakura-darkpink-theme/issues) 提交 Issue
2. 提交包含改进的 Pull Request

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。

## 💖 支持

如果你喜欢这个主题，请：
- ⭐ 给仓库点星
- 📝 在 VS Code 市场留下评价
- 🐛 报告任何发现的问题
- 💡 提出改进建议

---

**用 ❤️ 制作，作者：[yumiaoyi-o](https://github.com/yumiaoyi-o)**

*为喜欢蕾缪安主题的开发者而生！* 🌸
