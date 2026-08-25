#!/system/bin/sh
#==========================================================
# AutoReboot - KernelSU Module
# customize.sh - 安装脚本
#==========================================================

ui_print "AutoReboot 自动重启 正在安装..."
ui_print ""
ui_print "  [功能] 自定义手机自动重启"
ui_print "  - 一次性定时 / 每天 / 每周 / 每月 / 间隔 五种模式"
ui_print "  - WebUI 可视化设置, 开机自动生效"
ui_print "  - 重启前自动写日志, 支持试运行验证"
ui_print ""
ui_print "  [使用] KernelSU 管理器 -> 模块 -> AutoReboot -> WebUI"
ui_print "         或命令行: sh /data/adb/reboot_guard/scripts/rebootctl.sh"
ui_print ""

# 设置脚本权限
set_perm_recursive "$MODPATH" 0 0 0755 0755
