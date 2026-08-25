#!/system/bin/sh
#==========================================================
# AutoReboot - KernelSU Module
# scripts/daemon.sh - 后台调度守护进程
# 支持 once / daily / weekly / monthly / interval 五种模式
# DRY_RUN=1 时不真正重启 (本机测试)
#==========================================================

MODDIR=${0%/*}
if [ -f "$MODDIR/config.sh" ]; then
    . "$MODDIR/config.sh"
elif [ -f "/data/adb/reboot_guard/scripts/config.sh" ]; then
    . "/data/adb/reboot_guard/scripts/config.sh"
fi

mkdir -p "$STATE_DIR" 2>/dev/null
echo $$ > "$DATA_DIR/daemon.pid" 2>/dev/null

# 时间比较辅助 (格式均为 YYYY-MM-DD HH:MM, 字典序即时间序)
ts_le() { [ "$1" \< "$2" ] || [ "$1" = "$2" ]; }
ts_ge() { [ "$1" \> "$2" ] || [ "$1" = "$2" ]; }

LAST_TS_FILE="$STATE_DIR/last_ts"
TRIGGER_MARK="$STATE_DIR/last_trigger"

if [ "$ENABLED" != "1" ]; then
    log_msg "Daemon: 未启用 (ENABLED=$ENABLED), 退出"
    exit 0
fi

# interval 模式首次启动: 记录计时起点
if [ "$MODE" = "interval" ] && [ ! -f "$LAST_TS_FILE" ]; then
    date +%s > "$LAST_TS_FILE" 2>/dev/null
    log_msg "Interval 计时起点初始化: epoch=$(cat "$LAST_TS_FILE" 2>/dev/null)"
fi

log_msg "========================================"
log_msg "AutoReboot Daemon Started"
log_msg "Mode: $MODE | Enabled: $ENABLED | Check: ${CHECK_INTERVAL}s"
log_msg "Dry-run: $DRY_RUN | Reboot cmd: $REBOOT_CMD"
log_msg "========================================"

while true; do
    sleep "$CHECK_INTERVAL" 2>/dev/null
    [ "$ENABLED" = "1" ] || break

    now=$(date '+%Y-%m-%d %H:%M')
    now_epoch=$(date +%s)
    now_hm=$(date '+%H:%M')
    trigger=0
    reason=""

    case "$MODE" in
        once)
            if [ -n "$ONCE_DATETIME" ] && ts_ge "$now" "$ONCE_DATETIME"; then
                trigger=1; reason="once 到达 $ONCE_DATETIME"
            fi
            ;;
        daily)
            if [ "$now_hm" = "$DAILY_TIME" ]; then
                trigger=1; reason="daily $DAILY_TIME"
            fi
            ;;
        weekly)
            target_u=7; [ "$WEEK_DAY" != "0" ] && target_u=$WEEK_DAY
            if [ "$(date '+%u')" = "$target_u" ] && [ "$now_hm" = "$WEEK_TIME" ]; then
                trigger=1; reason="weekly 周$WEEK_DAY $WEEK_TIME"
            fi
            ;;
        monthly)
            if [ "$((10#$(date '+%d')))" = "$MONTH_DAY" ] && [ "$now_hm" = "$MONTH_TIME" ]; then
                trigger=1; reason="monthly ${MONTH_DAY}日 $MONTH_TIME"
            fi
            ;;
        interval)
            last=$(cat "$LAST_TS_FILE" 2>/dev/null)
            case "$last" in ''|*[!0-9]*) last="" ;; esac
            if [ -n "$last" ] && [ $((now_epoch - last)) -ge "$INTERVAL_SEC" ]; then
                trigger=1; reason="interval 已间隔 $((now_epoch - last))s >= ${INTERVAL_SEC}s"
                date +%s > "$LAST_TS_FILE" 2>/dev/null
            fi
            ;;
    esac

    if [ "$trigger" = "1" ]; then
        # 防同一分钟重复触发 (时钟模式)
        if [ "$(cat "$TRIGGER_MARK" 2>/dev/null)" = "$now" ]; then
            continue
        fi
        echo "$now" > "$TRIGGER_MARK" 2>/dev/null
        log_warn "触发重启: $reason"
        if [ "$DRY_RUN" = "1" ]; then
            log_msg "[DRY-RUN] 不真正重启 (仅模拟)"
        else
            log_warn "执行: $REBOOT_CMD"
            sleep 2
            $REBOOT_CMD 2>> "$LOG_FILE" || log_err "重启命令执行失败"
            log_err "重启命令未生效? 继续监控"
        fi
        if [ "$MODE" = "once" ]; then
            # 一次性模式触发后自动禁用, 防止重复
            if [ -f "$USER_CONF" ]; then
                sed -i 's/^ENABLED=.*/ENABLED=0/' "$USER_CONF" 2>/dev/null
            else
                echo "ENABLED=0" > "$USER_CONF" 2>/dev/null
            fi
            ENABLED=0
            log_msg "once 已触发, 自动禁用 (ENABLED=0)"
            break
        fi
    fi
done

log_msg "Daemon 退出"
exit 0
