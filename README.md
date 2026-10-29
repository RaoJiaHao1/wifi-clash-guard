# Wi-Fi Clash Guard

连接指定 Wi-Fi 时自动退出 Clash。适用于 Windows 10 / 11，支持常见 Clash Verge、Clash for Windows、Clash Party 和 Mihomo 进程。

用户只需修改 Wi-Fi 名称。程序通过 Windows 任务计划程序响应无线连接事件，平时没有常驻监测进程。

## 快速使用

1. 下载并完整解压 `WifiClashGuard-v1.0.0-win.zip`，将文件夹放在固定、当前用户可写的位置。
2. 用记事本打开 `config.json`，把 `YOUR_WIFI_NAME` 替换为要匹配的 Wi-Fi 名称或前缀。
3. 双击 `Install.cmd`。安装成功后，登录、Wi-Fi 连接成功和每 5 分钟的补充检查都会自动运行。

配置示例：

```json
{
  "wifiName": "Campus_WiFi"
}
```

该配置会匹配 `Campus_WiFi`、`Campus_WiFi_Guest` 等以此开头的名称，不区分大小写。星号等字符按字面匹配；无需添加通配符。支持中文名称，配置文件使用 UTF-8 编码。空名称和默认占位符会被拒绝，避免误匹配。

修改配置后下一次检查就会生效，无需重新编译或安装。移动目录前先卸载，再从新目录重新安装。

如果使用 GitHub 源码下载：先双击 `Install.cmd`，它会创建 `config.json` 并提示修改；填写 Wi-Fi 名称后再运行一次。源码版会调用系统 .NET Framework 编译器构建 EXE。

## 常用操作

| 文件 | 作用 |
| --- | --- |
| `Install.cmd` | 安装当前用户的自动检查任务，并立即检查 |
| `Enable.cmd` | 恢复已停用的任务并立即检查 |
| `Disable.cmd` | 停用所有自动检查，包括登录触发 |
| `Status.cmd` | 查看启用状态、上次结果和下次补充检查时间 |
| `Diagnose.cmd` | 只读检查，不关闭任何进程 |
| `Uninstall.cmd` | 移除任务，保留本地配置和日志 |

通过当前用户的交互式会话执行，无需保存密码。若任务安装返回“拒绝访问”，可在同一用户的管理员终端中运行安装脚本；不要切换成其他用户安装。

## 工作方式

- Windows WLAN-AutoConfig 成功连接事件 `8001` 触发检查，延迟约 1 秒。
- 登录后延迟约 15 秒检查；每 5 分钟再补充检查一次。
- 读取当前已连接的 SSID，不扫描周围热点、不发送外部请求。
- 匹配后关闭已知 Clash 客户端及核心进程，并于约 2、5、10 秒后复查。
- 检查完退出。通常无常驻内存占用；每次启动有短暂的进程和 .NET 初始化开销。
- 允许在电池供电时执行，不唤醒睡眠中的电脑；任务重叠时忽略新的执行请求。

退出意味着终止进程。未保存的客户端界面操作可能丢失。系统代理和 TUN 的恢复取决于客户端，建议确认客户端退出后的联网行为。离开目标 Wi-Fi 后需要按需手动重启 Clash。

## 隐私

- 仓库仅包含示例配置。
- `config.json`、`runtime/` 和构建产物已加入 `.gitignore`。
- 日志只记录匹配与否、已知进程名及错误类型/错误码；不记录 SSID、PID、MAC、用户名或异常中的完整路径。
- 诊断只报告配置状态、匹配与否和目标进程数量。
- 用户标识与安装目录仅在本机生成的计划任务中使用，卸载时删除任务；本程序不会导出任务 XML。
- 发布包通过白名单组装，不包含本地配置或日志。公开问题反馈前仍请检查截图和手动提供的信息。

## 故障排查

1. 运行 `Status.cmd`，确认任务已启用且上次结果为 `0`。首次执行前可能显示尚未运行；`267009` 表示仍在运行。
2. 运行 `Diagnose.cmd`：`Target Wi-Fi matched` 表示名称匹配结果，`Recognized target count` 表示可识别的 Clash 进程数量。
3. 查看 `runtime/guard.log`。退出码 `1` 表示查询或进程关闭失败；`2` 表示配置或命令行无效。
4. 无线查询错误 `5` 通常与权限或 Windows 定位隐私设置有关。检查定位设置、WLAN AutoConfig 服务，以及事件查看器中 `Microsoft-Windows-WLAN-AutoConfig/Operational` 日志是否启用。
5. `Stop failed` 可能由权限不同导致；以管理员身份运行的 Clash 无法保证被普通用户任务关闭。服务自动拉起核心、修改过的客户端或未知进程名称也可能需要调整源码中的已知名单。

任务名以 `WifiClashGuard-` 开头，后缀按当前用户生成。每个用户保留一份安装，安装器会拒绝覆盖其他目录的任务。

## 构建与测试

需要 Windows PowerShell 5.1、.NET Framework 4.8 和 Windows 任务计划服务；无需额外 NuGet 包或第三方运行时。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build.ps1 -Test -Package
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-TaskXml.ps1
```

单元测试覆盖配置校验、前缀与中文匹配、非目标网络不执行关闭、Native WLAN 结构解码及日志脱敏。任务 XML 测试使用 Windows 的 `TASK_VALIDATE_ONLY` 验证语法，不注册任务或切换网络。

构建生成 `bin/WifiClashGuard.exe`；发布包及 SHA-256 校验值位于 `dist/`。源码不提交 `bin/`、`dist/`、`config.json` 或 `runtime/`。将生成的 Windows ZIP 与校验文件上传至 GitHub Release 即可供普通用户下载。

## License

[MIT](LICENSE)
