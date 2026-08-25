#!/system/bin/sh
#==========================================================
# AutoReboot - KernelSU Module
# scripts/restart.sh - 安全重启 AutoReboot 服务
# 供 WebUI / rebootctl.sh 调用 (修改计划后重启服务生效)
#==========================================================

SELF_DIR=${0%/*}
if [ -f "$SELF_DIR/../service.sh" ]; then
    MODDIR=$(cd "$SELF_DIR/.." 2>/dev/null && pwd)
else
    MODDIR=/data/adb/modules/auto_reboot
fi
DATA_DIR="${REBOOT_GUARD_DATA_DIR:-/data/adb/reboot_guard}"

# 1. 停止守护进程与主服务 (按 PID 精确停止)
if [ -f "$DATA_DIR/daemon.pid" ]; then
    kill "$(cat "$DATA_DIR/daemon.pid" 2>/dev/null)" 2>/dev/null
fi
if [ -f "$DATA_DIR/service.pid" ]; then
    kill "$(cat "$DATA_DIR/service.pid" 2>/dev/null)" 2>/dev/null
fi
sleep 1

# 2. 重新启动服务
nohup sh "$MODDIR/service.sh" >/dev/null 2>&1 &

echo "RESTARTED"
