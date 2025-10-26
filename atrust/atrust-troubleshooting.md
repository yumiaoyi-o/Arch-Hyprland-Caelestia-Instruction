## aTrust 崩溃与修复记录 (可复现步骤)

日期: 2025-10-25

目标：记录在本机遇到的 aTrust GUI 崩溃问题、诊断步骤、使用的命令、最终修复（含持久化）以及清理/回滚方法，保证团队或自己可以 100% 按步骤复现并在相似系统上应用相同修复。

注意事项与前提
- 本文档假设运行环境为 Arch Linux（systemd），有 sudo 权限用于安装持久化修复（pacman hook、tmpfiles、systemd drop-in）。
- 在执行带 sudo 的命令时会提示输入密码，请在安全环境下操作。
- 本文记录的路径以目标系统为准：`/usr/share/sangfor/.aTrust` 为 aTrust 原始期望的运行时路径；为避免在 `/usr` 下创建运行时文件，我们使用用户目录 `~/.aTrust` 并创建符号链接。

问题描述（复现现象）
- aTrust tray 启动时 GUI 闪退，同时日志和 journal 显示：

  rpc server start listen:/usr/share/sangfor/.aTrust/var/run/… failed, reason: Error: listen EACCES: permission denied

- 同时在运行命令、使用 sudo 时看到：

  ERROR: ld.so: object '/home/USERNAME/.local/lib/libatrustredir.so' from LD_PRELOAD cannot be preloaded (cannot open shared object file): ignored.

  该信息来自之前为了诊断时临时创建的 LD_PRELOAD 测试库残留在会话环境中。

原始根因
- aTrust 的某个子进程尝试在包安装路径（/usr/share/sangfor/.aTrust/var/run）创建 UNIX-domain socket 或监听，但该路径属于 root/只读或权限不足，导致 listen() 返回 EACCES。因为该路径为包内路径（/usr/share/...）不是运行时目录，应用不能在升级后可靠创建运行时资源。

总体解决思路
1. 让 systemd 管理 aTrust 的守护进程（aTrustDaemon.service），由守护进程在系统范围创建并拥有所需 socket（通常由 root 或特定用户创建）。
2. 将包内固定的运行时路径 `/usr/share/sangfor/.aTrust` 重定向到用户目录下的 `~/.aTrust`（通过符号链接），便于用户空间运行并保证文件可访问。
3. 为了保证在包升级或系统重启后仍存在该符号链接和正确的文件，添加：
   - `/etc/pacman.d/hooks/atrust-symlink.hook`（pacman hook）在安装/升级后重新创建符号链接并尝试重启服务；
   - `/etc/tmpfiles.d/atrust.conf`（tmpfiles）在引导时创建路径或符号链接；
   - `/etc/systemd/system/aTrustDaemon.service.d/tmpfiles.conf`（systemd unit drop-in）确保 tmpfiles 在守护进程启动前运行。
4. 移除诊断时产生的临时文件、LD_PRELOAD 的环境残留，并归档/清理历史日志与 core dump 以节省磁盘空间。

详尽可复现步骤（按顺序）

1) 初始诊断（仅读日志）

  # 查看最近的 aTrust 日志（如果存在）
  tail -n 200 ~/.aTrust/logs/aTrustTray*.log || true

  # 查看 systemd 单元日志
  journalctl -u aTrustDaemon.service -n 200 --no-pager || true

2) 重现问题（在不改动系统的前提下，观察失败）

  # 启动或重启 tray/daemon，观察报错
  systemctl --user start aTrustDaemon.service  # 或 sudo systemctl start aTrustDaemon.service（视单元类型而定）

  # 若出现 EACCES 监听失败，记录报错。此时不要直接在 /usr 下修改权限。

3) 临时用户空间修复（不改 /usr）——用于验证思路

  # 在用户目录创建运行时目录并设置权限
  mkdir -p ~/.aTrust/var/run
  chmod 700 ~/.aTrust
  chown -R $(id -u):$(id -g) ~/.aTrust

  # 创建符号链接（只用于测试）
  sudo ln -sfn $HOME/.aTrust /usr/share/sangfor/.aTrust

  # 重新启动守护进程（或尝试重启）
  sudo systemctl try-restart aTrustDaemon.service

  # 检查服务状态和日志
  sudo systemctl status aTrustDaemon.service --no-pager
  journalctl -u aTrustDaemon.service -n 200 --no-pager

4) 持久化修复（写入到系统）

  文件：`/etc/pacman.d/hooks/atrust-symlink.hook`（示例内容）

  ````sh
  [Trigger]
  Type = Package
  Operation = Install, Upgrade
  Target = sangfor-* atrust*

  [Action]
  Description = ensure aTrust runtime symlink and restart daemon
  When = PostTransaction
  Exec = /usr/bin/ln -sfn /home/youruser/.aTrust /usr/share/sangfor/.aTrust
  Exec = /usr/bin/systemctl try-restart aTrustDaemon.service
  ````

  说明：将 `Target` 根据实际包名调整。PostTransaction 中的 ln 命令使用绝对路径（/home/youruser），pacman hook 以 root 身份运行。

  文件：`/etc/tmpfiles.d/atrust.conf`（示例内容）

  ````
  L /usr/share/sangfor/.aTrust - - - - /home/youruser/.aTrust
  d /home/youruser/.aTrust 0700 youruser youruser -
  ````

  说明：tmpfiles 可以在引导时创建目录与符号链接，确保路径在守护进程启动前存在。

  文件：`/etc/systemd/system/aTrustDaemon.service.d/tmpfiles.conf`（示例）

  ````ini
  [Unit]
  Before=aTrustDaemon.service
  Wants=systemd-tmpfiles-setup.service
  ````

  说明：该 drop-in 确保 tmpfiles 在 aTrust 守护启动前运行。

  执行并启用单元：

  sudo systemctl daemon-reload
  sudo systemctl enable --now aTrustDaemon.service

5) 移除诊断残留与日志归档（清理步骤）

  # 卸载 / 移除用于诊断的 LD_PRELOAD 库引用（当前会话）
  unset LD_PRELOAD

  # 在用户 shell 启动文件中删除对 libatrustredir.so 的引用
  # 例如：
  sed -i.bak -E '/libatrustredir.so/d; /LD_PRELOAD=.*libatrustredir\.so/d' ~/.bashrc ~/.profile ~/.pam_environment || true

  # 归档日志并清理（以日期命名的备份）
  sudo mkdir -p /var/backups
  DATE=$(date +%F)
  sudo tar -czf /var/backups/atrust-logs-${DATE}.tar.gz -C $HOME .aTrust/logs || true
  sudo rm -rf $HOME/.aTrust/logs/* || true
  mkdir -p $HOME/.aTrust/logs
  chown $(id -u):$(id -g) $HOME/.aTrust/logs
  chmod 700 $HOME/.aTrust/logs

  # 查找并（如需）归档 systemd 的 coredump 文件
  sudo find /var/lib/systemd/coredump -type f -iname '*aTrust*' -print
  # 若确认可删除，归档并删除：
  # sudo tar -czf /var/backups/atrust-coredumps-${DATE}.tar.gz /var/lib/systemd/coredump/*aTrust* && sudo rm -f /var/lib/systemd/coredump/*aTrust*

6) 验证（检查点）

  # 确认 LD_PRELOAD 不再出现
  /usr/bin/env | grep -i LD_PRELOAD || echo 'LD_PRELOAD not set'

  # 检查 aTrust 服务是否正常运行
  sudo systemctl status aTrustDaemon.service --no-pager
  journalctl -u aTrustDaemon.service -n 200 --no-pager

  # 再次触发 pacman hook 的行为（模拟）
  sudo ln -sfn $HOME/.aTrust /usr/share/sangfor/.aTrust
  sudo systemctl try-restart aTrustDaemon.service

回滚步骤（如果需要还原到安装前状态）
- 删除 pacman hook：
  sudo rm -f /etc/pacman.d/hooks/atrust-symlink.hook
- 删除 tmpfiles 与 drop-in：
  sudo rm -f /etc/tmpfiles.d/atrust.conf
  sudo rm -rf /etc/systemd/system/aTrustDaemon.service.d/tmpfiles.conf
  sudo systemctl daemon-reload
- 恢复原始目录（如果存在备份）：
  sudo rm -f /usr/share/sangfor/.aTrust
  sudo mv /usr/share/sangfor/.aTrust.bak /usr/share/sangfor/.aTrust  # 若此前有备份

重要备注与陷阱
- 不要直接对包安装目录（/usr/share/...）赋予永远的写权限给非 root 用户，这会破坏包管理安全模型。我们使用符号链接和由 systemd/tmpfiles 管理的路径来避免这种风险。
- pacman hook 中使用的路径必须是绝对的（例如 /home/youruser），且当以 root 身份运行时，$HOME 不会自动展开为普通用户的家目录；在 hook 中请显式写出 `/home/youruser`。
- LD_PRELOAD 的残留可能来自图形会话管理器或 systemd --user 环境（不是只有 shell 启动文件）。如果在注销并重新登录后 LD_PRELOAD 仍然存在，请检查：
  - `~/.config/environment.d/`
  - Display manager（GDM/SDDM）自定义环境配置
  - systemd user 服务文件或通过 loginctl 创建的环境变量

脚本说明（新增）

- 脚本路径：`./atrust-fix.sh`（与本文件同目录，即 `~/Documents/atrust/atrust-fix.sh`）
- 脚本功能概述：
  1. 创建并修复 `~/.aTrust` 运行时目录的权限；
  2. 在 `/usr/share/sangfor` 下创建指向 `~/.aTrust` 的符号链接（需要 sudo）；
  3. 在 `/etc` 下部署 pacman hook、tmpfiles 配置与 systemd drop-in，以保证修复持久化；
  4. 归档并清理 `~/.aTrust/logs`，并备份被修改的用户启动文件；
  5. 支持 dry-run（`--dry-run`）与实际应用（`--apply`）两种模式，默认交互式确认以降低风险。

- 使用方法：

  ```bash
  cd ~/Documents/atrust
  # 仅显示将要执行的操作（不做改动）
  ./atrust-fix.sh --dry-run

  # 仔细确认无误后执行实际更改（需要 sudo 提权时会提示）
  ./atrust-fix.sh --apply
  ```

- 注意：脚本会在修改前对用户级文件做备份（在同一目录下产生 `.bak-<timestamp>`），并在需要写入系统文件时使用 `sudo`。

附：我执行过的关键命令（历史回放）

  # 1. 创建用户运行时目录并修复权限
  mkdir -p ~/.aTrust/var/run
  chown -R $(id -u):$(id -g) ~/.aTrust
  chmod -R u+rwX ~/.aTrust

  # 2. 创建符号链接到 /usr 下（需要 sudo）
  sudo ln -sfn $HOME/.aTrust /usr/share/sangfor/.aTrust

  # 3. 为持久化创建 pacman hook（示例）并设置权限（以 root 写入）
  # 文件内容见上文；写入后：
  sudo chown root:root /etc/pacman.d/hooks/atrust-symlink.hook
  sudo chmod 644 /etc/pacman.d/hooks/atrust-symlink.hook

  # 4. 启用并重载 systemd
  sudo systemctl daemon-reload
  sudo systemctl enable --now aTrustDaemon.service

  # 5. 清理诊断文件与 LD_PRELOAD
  unset LD_PRELOAD
  sed -i.bak -E '/libatrustredir.so/d; /LD_PRELOAD=.*libatrustredir\\.so/d' ~/.bashrc ~/.profile ~/.pam_environment || true

结束语
-----
该文档旨在将我为解决 aTrust 崩溃而做的所有可复现步骤记录完整。若你要在另一台机器上复现，请把 `youruser` 替换为目标机器的用户名并以 root 权限（sudo）运行涉及系统路径修改的命令。若需要，我可以把本文档转换为脚本（带有交互确认）来自动化这些步骤。
