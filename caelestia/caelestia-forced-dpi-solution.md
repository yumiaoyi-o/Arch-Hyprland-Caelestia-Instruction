# Caelestia Shell 强制全局缩放（forced-DPI）解决方案

下面是我们为 `caelestia shell -d` 添加 forced-DPI（全局整体放大）所采取的完整实现、用法、设计权衡和故障排查步骤。

## 目标
- 在不修改 QML 源码的前提下，让 Caelestia Shell 在启动时整体放大（类似 Hyprland 的 monitor 缩放）。
- 提供简单命令行方式（wrapper），默认使用环境变量以影响 Qt/GTK 层的整体缩放；保留向 JSON 注入的备选方案。

## 关键内容
- 脚本位置（仓库）：`bin/caelestia-forceddpi`
- 安装到本地：`~/.local/bin/caelestia-forceddpi`
- 支持参数：
  - `--forced-dpi=<value>` 或 `--forceddpi <value>`：例如 `--forced-dpi=150`。
  - `--use-json`：使用 JSON 注入模式（写入临时 `XDG_CONFIG_HOME/caelestia/shell.json` 覆盖 appearance.scale），适用于某些不会尊重 env 的场景。
  - `--dry-run`：仅显示将导出的环境变量或将写入的 JSON 文件内容。
  - `--restart`：提示需要重启已在运行的实例以让新配置生效（脚本不会强杀进程，需手动或另行运行 kill 命令）。

## 实现说明（高层）
- 默认（env-mode）：计算 `scale = DPI / 96`，并导出环境变量：
  - `QT_ENABLE_HIGHDPI_SCALING=1`
  - `QT_AUTO_SCREEN_SCALE_FACTOR=0`
  - `QT_SCALE_FACTOR=<scale>`
  - `GDK_DPI_SCALE=<scale>`
  - `CAELESTIA_FORCED_DPI=<dpi>`（应用可以选择读取）
- 可选（json-mode）：创建临时 `XDG_CONFIG_HOME`，写入合并后的 `caelestia/shell.json`，覆盖 `appearance.*.scale` 为 scale，exec `caelestia`。
- `--dry-run` 会输出将导出的 env 或写入的 JSON（便于验证）。

## 安装与使用
```bash
# 安装（仓库路径按实际替换）
mkdir -p ~/.local/bin
cp /path/to/repo/bin/caelestia-forceddpi ~/.local/bin/caelestia-forceddpi
chmod +x ~/.local/bin/caelestia-forceddpi

# 启动并应用 150 DPI（env-mode，默认）
~/.local/bin/caelestia-forceddpi --forced-dpi=150 shell -d

# 仅显示将导出的 env（dry-run）
~/.local/bin/caelestia-forceddpi --forced-dpi=150 --dry-run shell -d

# 使用 JSON 注入模式
~/.local/bin/caelestia-forceddpi --forced-dpi=150 --use-json shell -d
# dry-run
~/.local/bin/caelestia-forceddpi --forced-dpi=150 --use-json --dry-run shell -d
```

## 验证
- 查看进程：
```bash
ps -o pid,ppid,cmd -u $USER | grep -E "qs|caelestia" | grep -v grep
```
- 查看启动日志（示例）
```bash
tail -n 200 "$HOME/.cache/caelestia-forceddpi.log"
```
- 如果需要确认读取了临时 JSON：可用 `strace -e trace=openat` 跟踪（需要权限）并搜索 `shell.json` 打开路径。

## 故障排查
- 如果没有变化：
  - 确认你在运行的是安装后的 wrapper（`~/.local/bin/caelestia-forceddpi`），而不是旧脚本或直接调用的 `caelestia`。
  - 检查是否已有正在运行的实例（需要先停止/重启）。
  - 用 `--dry-run` 检查 env/JSON 输出是否正确。
- 如果部分元素未放大：
  - 尝试额外设置 `QT_FONT_DPI`，或调整 `QT_SCALE_FACTOR` 的取值；
  - 或使用 `--use-json` 强制覆盖应用内部 `appearance.scale` 值。

## 限制与后续改进
- 如果希望彻底把 `--forced-dpi` 变成原生 CLI 参数，需要在 Caelestia 源码中添加支持并实现热重载/daemon 配置重读功能（需要修改、编译并发布应用）。
- 可将 wrapper 注册为 systemd user 单元以替代原有启动方式，或制作 distro-specific 包装（如 Nix/NixOS、Debian package）来优雅集成。

---

此文件由会话脚本生成，记录了我们一起实现的非侵入式 forced-DPI 方案，保存在此处以便以后参考或进一步自动化。


### Quick fix: add missing variant to user scheme

The `caelestia` CLI expects the `scheme.json` to include a `variant` field. If it is missing, commands like `caelestia scheme set -n dynamic` will raise a KeyError.

I backed up and patched `~/.local/state/caelestia/scheme.json` to add `"variant": "tonalspot"`. If you prefer a different variant, edit that file and change `variant` to one of: tonalspot, vibrant, expressive, fidelity, fruitsalad, monochrome, neutral, rainbow, content.
