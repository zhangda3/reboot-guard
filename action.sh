#!/system/bin/sh
#==========================================================
# AutoReboot - KernelSU Module
# action.sh - KernelSU 管理器操作按钮
#==========================================================

MODDIR=${0%/*}
DATA_DIR="${REBOOT_GUARD_DATA_DIR:-/data/adb/reboot_guard}"
LOG_FILE="$DATA_DIR/reboot_guard.log"

[ -f "$MODDIR/scripts/config.sh" ] && . "$MODDIR/scripts/config.sh"
[ -f "$MODDIR/scripts/rebootctl.sh" ] && . "$MODDIR/scripts/rebootctl.sh"

echo "============================================"
echo "  AutoReboot 自动重启模块"
echo "============================================"
echo ""
echo "【服务状态】"
if [ -f "$DATA_DIR/service.pid" ] && kill -0 "$(cat "$DATA_DIR/service.pid" 2>/dev/null)" 2>/dev/null; then
    echo "  服务运行中 (PID $(cat "$DATA_DIR/service.pid"))"
else
    echo "  服务未运行"
fi
if [ -f "$DATA_DIR/daemon.pid" ] && kill -0 "$(cat "$DATA_DIR/daemon.pid" 2>/dev/null)" 2>/dev/null; then
    echo "  调度进程运行中 (PID $(cat "$DATA_DIR/daemon.pid"))"
else
    echo "  调度进程未运行"
fi
echo ""
echo "【计划状态】"
cmd_status
echo ""
echo "【常用命令】"
echo "  su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh status'"
echo "  su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh set daily 23:00'"
echo "  su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh set weekly 5 02:00'"
echo "  su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh set interval 6h'"
echo "  su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh disable'"
echo ""
echo "【日志】"
echo "  cat /data/adb/reboot_guard/reboot_guard.log"
echo "============================================"
