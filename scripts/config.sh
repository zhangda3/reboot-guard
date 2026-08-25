#!/system/bin/sh
#==========================================================
# AutoReboot - KernelSU Module
# scripts/config.sh - 配置 + 日志函数
#==========================================================

MODDIR=${0%/*}
# 数据目录支持环境变量覆盖 (便于本机模拟测试; 真机保持默认)
DATA_DIR="${REBOOT_GUARD_DATA_DIR:-/data/adb/reboot_guard}"
LOG_FILE="$DATA_DIR/reboot_guard.log"

#==================== 运行配置 ====================

# 总开关 (0=禁用 / 1=启用)
ENABLED=0

# 调度模式: once|daily|weekly|monthly|interval
MODE=once

# 一次性: 目标时间 "YYYY-MM-DD HH:MM"
ONCE_DATETIME=""

# 每天: "HH:MM"
DAILY_TIME="03:00"

# 每周: 星期几(0=周日,1=周一...6=周六) + "HH:MM"
WEEK_DAY=1
WEEK_TIME="03:00"

# 每月: 几号(1-31) + "HH:MM"
MONTH_DAY=1
MONTH_TIME="03:00"

# 间隔: 秒 (WebUI 支持 分钟/小时/天 换算, 命令行支持 Nh/Nm/Nd)
INTERVAL_SEC=3600

# 调度检查周期(秒)。时钟模式(once/daily/weekly/monthly)下建议 <=60 以保证分钟级命中
# 支持环境变量覆盖 (本机测试可设 1 加速)
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"

# 重启命令 (默认 reboot; 可改为 "svc power reboot" 或自定义)
REBOOT_CMD="${REBOOT_CMD:-reboot}"

# 试运行模式: 1 时不真正执行重启, 仅写日志 (本机测试用)
DRY_RUN="${DRY_RUN:-0}"

#==================== 日志函数 ====================

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" >> "$LOG_FILE"
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*" >> "$LOG_FILE"
}

log_err() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >> "$LOG_FILE"
}

#==================== 用户配置覆盖 ====================
# WebUI 或手动编辑 /data/adb/reboot_guard/user.conf 可覆盖以上默认值。
# 格式: 每行 KEY=值 (如 ENABLED=1, MODE=daily)。
USER_CONF="$DATA_DIR/user.conf"
if [ -f "$USER_CONF" ]; then
    grep -E '^[A-Z_][A-Z0-9_]*=' "$USER_CONF" > "$DATA_DIR/.cfg_loaded" 2>/dev/null
    [ -s "$DATA_DIR/.cfg_loaded" ] && . "$DATA_DIR/.cfg_loaded"
fi

#==================== 状态目录 ====================
# last_ts: interval 模式计时起点(epoch秒)
# last_trigger: 最近一次触发时刻 "YYYY-MM-DD HH:MM" (防同一分钟重复触发)
STATE_DIR="$DATA_DIR/state"
