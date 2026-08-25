#!/system/bin/sh
#==========================================================
# AutoReboot - KernelSU Module
# service.sh - 主服务: 开机后启动调度守护进程
#==========================================================

MODDIR=${0%/*}
DATA_DIR="${REBOOT_GUARD_DATA_DIR:-/data/adb/reboot_guard}"
LOG_FILE="$DATA_DIR/reboot_guard.log"

# 确保数据目录存在
mkdir -p "$DATA_DIR/scripts" "$DATA_DIR/state" 2>/dev/null

# 每次启动都同步脚本到 /data/adb (模块目录更新后重启服务即可用新脚本)
if [ -d "$MODDIR/scripts" ]; then
    cp -f "$MODDIR/scripts/"*.sh "$DATA_DIR/scripts/" 2>/dev/null
    chmod 755 "$DATA_DIR/scripts/"*.sh 2>/dev/null
fi

# 记录服务 PID (供 WebUI/restart.sh 精确重启)
echo $$ > "$DATA_DIR/service.pid" 2>/dev/null

# 加载配置 (if/elif 兜底, 避免 `.` 失败导致 shell 退出)
if [ -f "$DATA_DIR/scripts/config.sh" ]; then
    . "$DATA_DIR/scripts/config.sh"
elif [ -f "$MODDIR/scripts/config.sh" ]; then
    . "$MODDIR/scripts/config.sh"
fi

# 等待系统完全启动 (真机; 本机测试无 getprop 时跳过)
if command -v getprop >/dev/null 2>&1; then
    while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
        sleep 2
    done
    sleep 5
fi

log_msg "========================================"
log_msg "AutoReboot Service Starting"
log_msg "Kernel: $(uname -r 2>/dev/null)"
log_msg "Device: $(getprop ro.product.device 2>/dev/null)"
log_msg "Android: $(getprop ro.build.version.release 2>/dev/null)"
log_msg "Mode: $MODE | Enabled: $ENABLED | Dry-run: $DRY_RUN"
log_msg "========================================"

# 停止可能残留的旧守护进程
if [ -f "$DATA_DIR/daemon.pid" ]; then
    kill "$(cat "$DATA_DIR/daemon.pid" 2>/dev/null)" 2>/dev/null
    sleep 1
fi

# 计划启用时启动调度守护进程
if [ "$ENABLED" = "1" ]; then
    log_msg "Starting daemon (mode=$MODE)..."
    nohup sh "$DATA_DIR/scripts/daemon.sh" >/dev/null 2>&1 &
    log_msg "Daemon started, pid=$!"
else
    log_msg "Plan disabled, daemon not started"
fi

log_msg "Service ready"
