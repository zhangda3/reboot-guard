#!/system/bin/sh
#==========================================================
# AutoReboot - KernelSU Module
# uninstall.sh - 卸载时清理
#==========================================================

DATA_DIR="/data/adb/reboot_guard"

# 停止调度进程与服务
if [ -f "$DATA_DIR/daemon.pid" ]; then
    kill "$(cat "$DATA_DIR/daemon.pid" 2>/dev/null)" 2>/dev/null
fi
if [ -f "$DATA_DIR/service.pid" ]; then
    kill "$(cat "$DATA_DIR/service.pid" 2>/dev/null)" 2>/dev/null
fi
sleep 1

# 清理数据目录
rm -rf "$DATA_DIR" 2>/dev/null

echo "AutoReboot uninstalled at $(date '+%Y-%m-%d %H:%M:%S')" >> /data/adb/reboot_guard.log 2>/dev/null
