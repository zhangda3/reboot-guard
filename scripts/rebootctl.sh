#!/system/bin/sh
#==========================================================
# AutoReboot - KernelSU Module
# scripts/rebootctl.sh - 控制命令入口
#   status                      查看状态与下次重启时间
#   set once "YYYY-MM-DD HH:MM" 一次性定时
#   set daily "HH:MM"           每天
#   set weekly <0-6> "HH:MM"    每周 (0=周日)
#   set monthly <1-31> "HH:MM"  每月
#   set interval <秒|Nh|Nm|Nd>  间隔 (如 3600 / 6h / 30m / 2d)
#   enable | disable            启用 / 暂停计划
#   now [延时秒]                立即重启
#   reset                       恢复默认 (禁用)
#   log [行数]                  查看日志
#==========================================================

MODDIR=${0%/*}
if [ -f "$MODDIR/config.sh" ]; then
    . "$MODDIR/config.sh"
elif [ -f "/data/adb/reboot_guard/scripts/config.sh" ]; then
    . "/data/adb/reboot_guard/scripts/config.sh"
fi

#==================== 辅助函数 ====================

# 校验 "HH:MM"
valid_hhmm() {
    case "$1" in
        [0-9][0-9]:[0-9][0-9]) ;;
        *) return 1 ;;
    esac
    local h m
    h=$((10#${1%%:*})); m=$((10#${1##*:}))
    [ "$h" -le 23 ] && [ "$m" -le 59 ]
}

# 校验 "YYYY-MM-DD HH:MM"
valid_datetime() {
    date -d "$1" '+%Y-%m-%d %H:%M' >/dev/null 2>&1
}

# 解析间隔: 纯数字=秒, Nh/Nm/Nd 换算为秒
parse_interval() {
    local v=$1 n u
    case "$v" in
        *h) n=${v%h}; u=3600 ;;
        *m) n=${v%m}; u=60 ;;
        *d) n=${v%d}; u=86400 ;;
        *)  n=$v; u=1 ;;
    esac
    case "$n" in ''|*[!0-9]*) return 1 ;; esac
    [ "$n" -gt 0 ] || return 1
    echo $((n * u))
}

# 格式化间隔描述
fmt_interval() {
    local s=$1
    if [ $((s % 86400)) -eq 0 ]; then echo "$((s/86400))天"
    elif [ $((s % 3600)) -eq 0 ]; then echo "$((s/3600))小时"
    elif [ $((s % 60)) -eq 0 ]; then echo "$((s/60))分钟"
    else echo "${s}秒"; fi
}

# 重写 user.conf (保留用户意图, 结构干净)
write_conf() {
    {
        echo "# AutoReboot user config (由 WebUI / rebootctl 生成, 重启后保留)"
        echo "ENABLED=${ENABLED:-1}"
        echo "MODE=$MODE"
        case "$MODE" in
            once)     echo "ONCE_DATETIME=\"$ONCE_DATETIME\"" ;;
            daily)    echo "DAILY_TIME=\"$DAILY_TIME\"" ;;
            weekly)   echo "WEEK_DAY=$WEEK_DAY"; echo "WEEK_TIME=\"$WEEK_TIME\"" ;;
            monthly)  echo "MONTH_DAY=$MONTH_DAY"; echo "MONTH_TIME=\"$MONTH_TIME\"" ;;
            interval) echo "INTERVAL_SEC=$INTERVAL_SEC" ;;
        esac
    } > "$USER_CONF" 2>/dev/null
}

# 重启服务 (供 WebUI / set / enable / disable / reset 调用)
restart_service() {
    sh "$MODDIR/restart.sh" >/dev/null 2>&1
}

# 重启服务并定位模块根目录 (rebootctl.sh 位于 <mod>/scripts/)
# 在真机由 KernelSU 以 /data/adb/modules/auto_reboot/scripts/rebootctl.sh 调用,
# 本机测试时 scripts 与模块根同源, 由 restart.sh 内自动探测处理。

#==================== 状态 / 下次触发时间 ====================

# 时间比较辅助
ts_le() { [ "$1" \< "$2" ] || [ "$1" = "$2" ]; }
ts_ge() { [ "$1" \> "$2" ] || [ "$1" = "$2" ]; }

mode_desc() {
    case "$MODE" in
        once)     echo "一次性: $ONCE_DATETIME" ;;
        daily)    echo "每天: $DAILY_TIME" ;;
        weekly)   echo "每周: 周$WEEK_DAY $WEEK_TIME" ;;
        monthly)  echo "每月: ${MONTH_DAY}日 $MONTH_TIME" ;;
        interval) echo "间隔: 每 $(fmt_interval "$INTERVAL_SEC") 重启一次" ;;
        *)        echo "未设置" ;;
    esac
}

# 计算下一次触发时间
next_trigger() {
    [ "$ENABLED" = "1" ] || { echo "(计划未启用)"; return; }
    local now_hm ymd d day nxt target_u last now_epoch
    now_hm=$(date '+%H:%M')
    ymd=$(date '+%Y-%m-%d')
    case "$MODE" in
        once)
            if [ -n "$ONCE_DATETIME" ] && ts_ge "$ymd $now_hm" "$ONCE_DATETIME"; then
                echo "(已到时间, 等待触发)"
            else
                echo "$ONCE_DATETIME"
            fi
            ;;
        daily)
            if ts_le "$now_hm" "$DAILY_TIME"; then
                echo "$ymd $DAILY_TIME"
            else
                ymd=$(date -d "+1 day" '+%Y-%m-%d' 2>/dev/null)
                echo "$ymd $DAILY_TIME"
            fi
            ;;
        weekly)
            target_u=7; [ "$WEEK_DAY" != "0" ] && target_u=$WEEK_DAY
            d=0
            while [ "$d" -le 7 ]; do
                day=$(date -d "+$d day" '+%u' 2>/dev/null)
                if [ "$day" = "$target_u" ] && { [ "$d" -gt 0 ] || ts_le "$now_hm" "$WEEK_TIME"; }; then
                    nxt=$(date -d "+$d day" '+%Y-%m-%d' 2>/dev/null)
                    echo "$nxt $WEEK_TIME"
                    return
                fi
                d=$((d+1))
            done
            echo "(计算失败)"
            ;;
        monthly)
            d=0
            while [ "$d" -le 40 ]; do
                day=$((10#$(date -d "+$d day" '+%d' 2>/dev/null)))
                if [ "$day" = "$MONTH_DAY" ] && { [ "$d" -gt 0 ] || ts_le "$now_hm" "$MONTH_TIME"; }; then
                    nxt=$(date -d "+$d day" '+%Y-%m-%d' 2>/dev/null)
                    echo "$nxt $MONTH_TIME"
                    return
                fi
                d=$((d+1))
            done
            echo "(计算失败)"
            ;;
        interval)
            last=$(cat "$STATE_DIR/last_ts" 2>/dev/null)
            case "$last" in ''|*[!0-9]*) last="" ;; esac
            now_epoch=$(date +%s)
            if [ -z "$last" ]; then
                echo "$(date '+%Y-%m-%d %H:%M') (启用后开始计时)"
            else
                echo "$(date -d "@$((last + INTERVAL_SEC))" '+%Y-%m-%d %H:%M' 2>/dev/null)"
            fi
            ;;
        *) echo "(未设置)" ;;
    esac
}

cmd_status() {
    local svc=STOPPED daemon=STOPPED
    if [ -f "$DATA_DIR/service.pid" ] && kill -0 "$(cat "$DATA_DIR/service.pid" 2>/dev/null)" 2>/dev/null; then
        svc=RUNNING
    fi
    if [ -f "$DATA_DIR/daemon.pid" ] && kill -0 "$(cat "$DATA_DIR/daemon.pid" 2>/dev/null)" 2>/dev/null; then
        daemon=RUNNING
    fi
    echo "ENABLED=$ENABLED"
    echo "MODE=$MODE"
    echo "SERVICE=$svc"
    echo "DAEMON=$daemon"
    echo "DRY_RUN=$DRY_RUN"
    echo "DESC=$(mode_desc)"
    echo "NEXT=$(next_trigger)"
    echo "LAST=$(cat "$STATE_DIR/last_trigger" 2>/dev/null || echo none)"
    # 各模式参数 (供 WebUI 回显预填)
    echo "PARAM_ONCE=$ONCE_DATETIME"
    echo "PARAM_DAILY=$DAILY_TIME"
    echo "PARAM_WEEK_DAY=$WEEK_DAY"
    echo "PARAM_WEEK_TIME=$WEEK_TIME"
    echo "PARAM_MONTH_DAY=$MONTH_DAY"
    echo "PARAM_MONTH_TIME=$MONTH_TIME"
    echo "PARAM_INTERVAL=$INTERVAL_SEC"
}

#==================== 命令实现 ====================

cmd_set() {
    local mode=$1
    shift
    case "$mode" in
        once)
            [ $# -ge 1 ] || { echo "ERR: once 需要时间参数 \"YYYY-MM-DD HH:MM\""; return 1; }
            valid_datetime "$1" || { echo "ERR: 时间格式应为 YYYY-MM-DD HH:MM"; return 1; }
            MODE=once; ONCE_DATETIME="$1"
            ;;
        daily)
            [ $# -ge 1 ] || { echo "ERR: daily 需要时间参数 \"HH:MM\""; return 1; }
            valid_hhmm "$1" || { echo "ERR: 时间格式应为 HH:MM"; return 1; }
            MODE=daily; DAILY_TIME="$1"
            ;;
        weekly)
            [ $# -ge 2 ] || { echo "ERR: weekly 需要 星期(0-6) 和 \"HH:MM\""; return 1; }
            case "$1" in
                [0-6]) WEEK_DAY=$1 ;;
                *) echo "ERR: 星期应为 0-6 (0=周日)"; return 1 ;;
            esac
            valid_hhmm "$2" || { echo "ERR: 时间格式应为 HH:MM"; return 1; }
            MODE=weekly; WEEK_TIME="$2"
            ;;
        monthly)
            [ $# -ge 2 ] || { echo "ERR: monthly 需要 日(1-31) 和 \"HH:MM\""; return 1; }
            case "$1" in
                [1-9]|[12][0-9]|3[01]) MONTH_DAY=$1 ;;
                *) echo "ERR: 日应为 1-31"; return 1 ;;
            esac
            valid_hhmm "$2" || { echo "ERR: 时间格式应为 HH:MM"; return 1; }
            MODE=monthly; MONTH_TIME="$2"
            ;;
        interval)
            [ $# -ge 1 ] || { echo "ERR: interval 需要间隔 (秒 或 如 6h/30m/2d)"; return 1; }
            local sec
            sec=$(parse_interval "$1") || { echo "ERR: 间隔格式无效 (示例: 3600, 6h, 30m, 2d)"; return 1; }
            MODE=interval; INTERVAL_SEC=$sec
            ;;
        *)
            echo "ERR: 未知模式 $mode (once|daily|weekly|monthly|interval)"; return 1 ;;
    esac

    ENABLED=1
    write_conf
    # interval 模式重置计时起点
    if [ "$MODE" = "interval" ]; then
        date +%s > "$STATE_DIR/last_ts" 2>/dev/null
    else
        rm -f "$STATE_DIR/last_ts" 2>/dev/null
    fi
    restart_service
    echo "OK: 已设置 $mode 计划并启用: $(mode_desc)"
}

cmd_enable() {
    ENABLED=1; write_conf
    # interval 起点未初始化时补齐
    if [ "$MODE" = "interval" ] && [ ! -f "$STATE_DIR/last_ts" ]; then
        date +%s > "$STATE_DIR/last_ts" 2>/dev/null
    fi
    restart_service
    echo "OK: 计划已启用: $(mode_desc)"
}

cmd_disable() {
    ENABLED=0; write_conf
    restart_service
    echo "OK: 计划已暂停"
}

cmd_now() {
    local delay=${1:-0}
    case "$delay" in ''|*[!0-9]*) delay=0 ;; esac
    log_warn "手动触发重启 (delay=${delay}s)"
    if [ "$DRY_RUN" = "1" ]; then
        echo "OK: [DRY-RUN] 模拟立即重启 (delay=${delay}s)"
        log_msg "[DRY-RUN] would reboot in ${delay}s"
    else
        echo "OK: 系统将在 ${delay} 秒后重启"
        sleep "$delay"
        $REBOOT_CMD 2>&1 || echo "ERR: 重启命令执行失败"
    fi
}

cmd_reset() {
    rm -f "$USER_CONF" "$STATE_DIR/last_ts" "$STATE_DIR/last_trigger" 2>/dev/null
    ENABLED=0; MODE=once
    log_msg "配置已重置 (计划禁用)"
    restart_service
    echo "OK: 已重置为默认并禁用"
}

cmd_log() {
    local n=${1:-30}
    case "$n" in ''|*[!0-9]*) n=30 ;; esac
    tail -n "$n" "$LOG_FILE" 2>/dev/null || echo "(日志为空)"
}

#==================== 入口 (仅直接执行时分发, 被 source 时静默) ====================

if [ "${0##*/}" = "rebootctl.sh" ]; then
    mkdir -p "$DATA_DIR" "$STATE_DIR" 2>/dev/null
    CMD=${1:-}
    case "$CMD" in
        status)  cmd_status ;;
        set)     shift; cmd_set "$@" ;;
        enable)  cmd_enable ;;
        disable) cmd_disable ;;
        now)     shift; cmd_now "$@" ;;
        reset)   cmd_reset ;;
        log)     shift; cmd_log "$@" ;;
        *)
            echo "AutoReboot rebootctl"
            echo "用法:"
            echo "  rebootctl.sh status"
            echo "  rebootctl.sh set once \"YYYY-MM-DD HH:MM\""
            echo "  rebootctl.sh set daily \"HH:MM\""
            echo "  rebootctl.sh set weekly <0-6> \"HH:MM\""
            echo "  rebootctl.sh set monthly <1-31> \"HH:MM\""
            echo "  rebootctl.sh set interval <秒|Nh|Nm|Nd>"
            echo "  rebootctl.sh enable|disable"
            echo "  rebootctl.sh now [延时秒]"
            echo "  rebootctl.sh reset"
            echo "  rebootctl.sh log [行数]"
            ;;
    esac
fi
