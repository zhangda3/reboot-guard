# AutoReboot 自动重启模块

一个基于 KernelSU 的 Android 设备自动重启管理模块，支持 WebUI 可视化配置和多种调度模式。

## 📋 功能特性

- **五种调度模式**：
  - 一次性定时重启
  - 每天定点重启
  - 每周指定星期重启
  - 每月指定日期重启
  - 每隔一段时间（分钟/小时/天）重启

- **WebUI 可视化管理**：通过浏览器界面轻松配置重启计划
- **开机自动生效**：服务随系统启动自动运行
- **日志记录**：重启前自动记录日志，便于追踪和调试
- **试运行模式 (DRY_RUN)**：验证配置而不实际执行重启
- **精确进程管理**：支持 PID 跟踪和优雅启停

## 📦 安装要求

- **Root 权限**：需要 KernelSU 或 Magisk
- **Android 版本**：支持 GKI 内核设备（如 SM7675/blair 平台）
- **存储空间**：约 1MB

## 🔧 安装方法

### 方法一：KernelSU 管理器安装
1. 下载模块压缩包
2. 打开 KernelSU 管理器
3. 点击「模块」→「从本地安装」
4. 选择模块 zip 文件并安装
5. 重启设备

### 方法二：手动安装
```bash
adb push auto_reboot.zip /data/local/tmp/
adb shell
su
cd /data/local/tmp
ksu install auto_reboot.zip
reboot
```

## 🎮 使用方法

### WebUI 配置（推荐）
模块安装后，在 KernelSU 管理器中点击「AutoReboot 自动重启」进入 WebUI 界面，可可视化配置：
- 启用/禁用自动重启
- 选择调度模式
- 设置具体时间/间隔
- 查看运行状态和日志

### 命令行配置
通过 `rebootctl.sh` 脚本进行高级配置：

```bash
# 查看状态与下次重启时间
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh status'

# 设置每天 23:00 重启
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh set daily 23:00'

# 设置每周五 02:00 重启 (0=周日, 5=周五)
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh set weekly 5 02:00'

# 设置每月 15 号 03:30 重启
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh set monthly 15 03:30'

# 设置每 6 小时重启一次
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh set interval 6h'

# 设置每 30 分钟重启一次
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh set interval 30m'

# 设置每 2 天重启一次
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh set interval 2d'

# 设置一次性定时重启 (2024-12-31 23:59)
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh set once "2024-12-31 23:59"'

# 立即重启（可选延时 10 秒）
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh now 10'

# 启用/禁用计划
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh enable'
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh disable'

# 恢复默认设置（禁用）
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh reset'

# 查看最近 50 行日志
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh log 50'
```

### KernelSU 操作按钮
在 KernelSU 管理器中点击模块卡片上的按钮，可查看：
- 服务和调度进程运行状态
- 当前计划状态
- 常用命令提示
- 日志位置

## 📁 目录结构

```
/data/adb/modules/auto_reboot/
├── module.prop          # 模块配置文件
├── service.sh           # 主服务脚本（开机启动）
├── action.sh            # KernelSU 操作按钮脚本
├── uninstall.sh         # 卸载清理脚本
├── customize.sh         # 自定义配置脚本
├── scripts/
│   ├── config.sh        # 配置管理
│   ├── daemon.sh        # 调度守护进程
│   ├── rebootctl.sh     # 控制命令入口
│   └── restart.sh       # 重启辅助脚本
└── webroot/
    └── index.html       # WebUI 界面

/data/adb/reboot_guard/  # 运行时数据目录
├── scripts/             # 同步的脚本副本
├── state/               # 状态文件
├── service.pid          # 服务进程 PID
├── daemon.pid           # 守护进程 PID
└── reboot_guard.log     # 运行日志
```

## ⚙️ 配置文件

编辑 `/data/adb/reboot_guard/scripts/config.sh` 可修改以下参数：

```bash
ENABLED=1          # 是否启用 (1=启用, 0=禁用)
MODE=daily         # 调度模式 (once/daily/weekly/monthly/interval)
SCHEDULE_TIME=""   # 定时时间 (格式依模式而定)
DRY_RUN=0          # 试运行模式 (1=仅记录日志不重启)
LOG_LEVEL=info     # 日志级别 (debug/info/warn/error)
```

## 📊 日志查看

```bash
# 查看完整日志
cat /data/adb/reboot_guard/reboot_guard.log

# 实时跟踪日志
tail -f /data/adb/reboot_guard/reboot_guard.log

# 通过命令查看最后 100 行
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh log 100'
```

## 🛑 卸载方法

### 方法一：KernelSU 管理器
1. 打开 KernelSU 管理器
2. 进入「模块」页面
3. 找到「AutoReboot 自动重启」
4. 点击垃圾桶图标卸载
5. 重启设备

### 方法二：命令行
```bash
su
rm -rf /data/adb/modules/auto_reboot
rm -rf /data/adb/reboot_guard
reboot
```

## 🔍 故障排查

### 服务未启动
```bash
# 检查服务状态
ls -la /data/adb/reboot_guard/*.pid

# 手动启动服务
sh /data/adb/modules/auto_reboot/service.sh &
```

### 计划不执行
```bash
# 检查是否启用
su -c 'sh /data/adb/reboot_guard/scripts/rebootctl.sh status'

# 检查 DRY_RUN 模式
cat /data/adb/reboot_guard/scripts/config.sh | grep DRY_RUN

# 查看日志定位问题
cat /data/adb/reboot_guard/reboot_guard.log
```

### WebUI 无法访问
1. 确认模块已正确安装
2. 检查 KernelSU 管理器版本是否支持 WebUI
3. 清除 KernelSU 管理器缓存后重试

## 📝 注意事项

1. **数据安全**：重启前请保存重要数据，避免未保存的工作丢失
2. **试运行验证**：首次使用建议开启 `DRY_RUN=1` 验证配置
3. **时间格式**：严格遵循 24 小时制 (HH:MM)
4. **周几定义**：0=周日, 1=周一, ..., 6=周六
5. **间隔单位**：支持秒(纯数字)、分钟(m)、小时(h)、天(d)
6. **系统兼容性**：部分定制 ROM 可能需要额外适配

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目基于开源协议发布，详见 LICENSE 文件。

## 👨‍💻 作者

KernelSU-Tools

---

**温馨提示**：自动重启功能可能导致数据丢失，请谨慎使用并确保重要数据已备份。
