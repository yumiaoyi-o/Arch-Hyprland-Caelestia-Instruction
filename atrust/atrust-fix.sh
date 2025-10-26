#!/usr/bin/env bash
set -euo pipefail

# aTrust 修复与持久化脚本
# 使用说明：
#   - 先运行 dry-run 查看会执行的操作：
#       ./atrust-fix.sh --dry-run
#   - 确认无误后以普通用户运行并允许脚本用 sudo 提权执行系统范围的更改：
#       ./atrust-fix.sh --apply
#
# 功能概览：
#   - 在用户目录创建 ~/.aTrust 并修复权限
#   - 在 /usr/share/sangfor/ 创建指向 ~/.aTrust 的符号链接（需 sudo）
#   - 在 /etc 下部署 pacman hook、tmpfiles 配置与 systemd unit drop-in（需 sudo）
#   - 归档并清理 ~/.aTrust/logs（备份到 /var/backups）
#   - 从常见用户启动文件中删除 LD_PRELOAD 到 libatrustredir 的残留
#
# 安全与回滚策略：
#   - 默认以 dry-run 模式运行，不会做破坏性改动
#   - 对于会改写系统文件的操作，会在目标位置先创建 .bak 备份
#   - 执行前会进行交互确认

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
USER_NAME=${SUDO_USER:-$(whoami)}
USER_HOME=$(eval echo "~${USER_NAME}")
DATE=$(date +%F_%H%M%S)
DRY_RUN=true

PACMAN_HOOK_PATH="/etc/pacman.d/hooks/atrust-symlink.hook"
TMPFILES_PATH="/etc/tmpfiles.d/atrust.conf"
SYSTEMD_DROPIN_DIR="/etc/systemd/system/aTrustDaemon.service.d"
SYSTEMD_DROPIN_PATH="$SYSTEMD_DROPIN_DIR/tmpfiles.conf"

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo "+DRYRUN: $*"
  else
    echo "+RUN : $*"
    eval "$@"
  fi
}

require_sudo() {
  if [ "$DRY_RUN" = true ]; then
    echo "(dry-run) would check for sudo availability"
    return 0
  fi
  if ! sudo -v; then
    echo "sudo unavailable or authentication failed; aborting" >&2
    exit 1
  fi
}

confirm() {
  if [ "$DRY_RUN" = true ]; then
    echo "(dry-run) auto-confirm"
    return 0
  fi
  read -r -p "$1 [y/N]: " ans
  case "$ans" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) echo "aborted by user"; return 1 ;;
  esac
}

create_user_runtime() {
  echo "== 创建用户运行时目录: $USER_HOME/.aTrust/var/run"
  run_cmd "mkdir -p '$USER_HOME/.aTrust/var/run'"
  run_cmd "chmod 700 '$USER_HOME/.aTrust'"
  run_cmd "chown -R $USER_NAME:'$(id -g $USER_NAME)' '$USER_HOME/.aTrust'"
}

create_symlink_in_usr() {
  echo "== 在 /usr/share/sangfor 创建或更新符号链接 -> $USER_HOME/.aTrust (需要 sudo)"
  require_sudo
  run_cmd "sudo ln -sfn '$USER_HOME/.aTrust' /usr/share/sangfor/.aTrust"
}

deploy_pacman_hook() {
  echo "== 部署 pacman hook 到 $PACMAN_HOOK_PATH (需要 sudo)"
  require_sudo
  local tmpfile
  tmpfile=$(mktemp)
  cat > "$tmpfile" <<EOF
[Trigger]
Type = Package
Operation = Install, Upgrade
Target = sangfor-* atrust*

[Action]
Description = ensure aTrust runtime symlink and restart daemon
When = PostTransaction
Exec = /usr/bin/ln -sfn $USER_HOME/.aTrust /usr/share/sangfor/.aTrust
Exec = /usr/bin/systemctl try-restart aTrustDaemon.service
EOF
  run_cmd "sudo cp '$tmpfile' '$PACMAN_HOOK_PATH'"
  run_cmd "sudo chown root:root '$PACMAN_HOOK_PATH'"
  run_cmd "sudo chmod 644 '$PACMAN_HOOK_PATH'"
  rm -f "$tmpfile"
}

deploy_tmpfiles() {
  echo "== 部署 tmpfiles 到 $TMPFILES_PATH (需要 sudo)"
  require_sudo
  local tmpfile
  tmpfile=$(mktemp)
  cat > "$tmpfile" <<EOF
L /usr/share/sangfor/.aTrust - - - - $USER_HOME/.aTrust
d $USER_HOME/.aTrust 0700 $USER_NAME $USER_NAME -
EOF
  run_cmd "sudo cp '$tmpfile' '$TMPFILES_PATH'"
  run_cmd "sudo chown root:root '$TMPFILES_PATH'"
  run_cmd "sudo chmod 644 '$TMPFILES_PATH'"
  rm -f "$tmpfile"
}

deploy_systemd_dropin() {
  echo "== 部署 systemd unit drop-in 到 $SYSTEMD_DROPIN_PATH (需要 sudo)"
  require_sudo
  run_cmd "sudo mkdir -p '$SYSTEMD_DROPIN_DIR'"
  local tmpfile
  tmpfile=$(mktemp)
  cat > "$tmpfile" <<EOF
[Unit]
Before=aTrustDaemon.service
Wants=systemd-tmpfiles-setup.service
EOF
  run_cmd "sudo cp '$tmpfile' '$SYSTEMD_DROPIN_PATH'"
  run_cmd "sudo chown root:root '$SYSTEMD_DROPIN_PATH'"
  run_cmd "sudo chmod 644 '$SYSTEMD_DROPIN_PATH'"
  rm -f "$tmpfile"
}

archive_and_clean_logs() {
  echo "== 归档并清理 $USER_HOME/.aTrust/logs"
  if [ -d "$USER_HOME/.aTrust/logs" ]; then
    require_sudo
    run_cmd "sudo mkdir -p /var/backups"
    run_cmd "sudo tar -czf /var/backups/atrust-logs-${DATE}.tar.gz -C '$USER_HOME' .aTrust/logs || true"
    run_cmd "sudo rm -rf '$USER_HOME/.aTrust/logs'/* || true"
    run_cmd "mkdir -p '$USER_HOME/.aTrust/logs'"
    run_cmd "sudo chown -R $USER_NAME:'$(id -g $USER_NAME)' '$USER_HOME/.aTrust/logs'"
    run_cmd "sudo chmod 700 '$USER_HOME/.aTrust/logs'"
    echo "archive saved to /var/backups/atrust-logs-${DATE}.tar.gz"
  else
    echo "no logs directory at $USER_HOME/.aTrust/logs, skipping"
  fi
}

remove_ld_preload_refs() {
  echo "== 从常见的 shell 启动文件中移除对 libatrustredir.so 的引用（会先备份原文件）"
  local files=("$USER_HOME/.bashrc" "$USER_HOME/.profile" "$USER_HOME/.bash_profile" "$USER_HOME/.pam_environment")
  for f in "${files[@]}"; do
    if [ -f "$f" ]; then
      run_cmd "cp -a '$f' '$f.bak-${DATE}'"
      run_cmd "sed -i -E '/libatrustredir.so/d; /LD_PRELOAD=.*libatrustredir\\.so/d; /export LD_PRELOAD=.*libatrustredir\\.so/d' '$f' || true"
      echo "cleaned $f (backup at $f.bak-${DATE})"
    fi
  done
  if [ -d "$USER_HOME/.profile.d" ]; then
    for s in "$USER_HOME/.profile.d"/*; do
      [ -f "$s" ] || continue
      if grep -q "libatrustredir.so" "$s" 2>/dev/null || grep -q "LD_PRELOAD" "$s" 2>/dev/null; then
        run_cmd "cp -a '$s' '$s.bak-${DATE}'"
        run_cmd "sed -i -E '/libatrustredir.so/d; /LD_PRELOAD=.*libatrustredir\\.so/d; /export LD_PRELOAD=.*libatrustredir\\.so/d' '$s' || true"
        echo "cleaned $s (backup at $s.bak-${DATE})"
      fi
    done
  fi
}

main() {
  if [ "$#" -eq 0 ]; then
    echo "Usage: $0 --dry-run | --apply"
    exit 1
  fi

  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --apply)
      DRY_RUN=false
      ;;
    *)
      echo "unknown arg: $1"; exit 1;;
  esac

  echo "Script mode: ${DRY_RUN:+dry-run (no destructive changes)}"

  echo; create_user_runtime

  if confirm "继续并在 /usr 下创建符号链接及部署系统文件？（这需要 sudo）"; then
    create_symlink_in_usr
    deploy_pacman_hook
    deploy_tmpfiles
    deploy_systemd_dropin
    run_cmd "sudo systemctl daemon-reload"
    run_cmd "sudo systemctl enable --now aTrustDaemon.service || true"
  else
    echo "跳过系统级部署"
  fi

  if confirm "归档并清理用户日志并删除 LD_PRELOAD 引用？"; then
    archive_and_clean_logs
    remove_ld_preload_refs
  else
    echo "跳过日志归档/清理与 LD_PRELOAD 清理"
  fi

  echo "完成。请注销并重新登录（或重启相关用户服务/会话）以保证环境变量清理生效。"
}

main "$@"
