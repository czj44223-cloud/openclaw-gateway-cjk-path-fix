# OpenClaw Gateway Windows 中文路径启动失败修复

> 修复 OpenClaw Gateway 在 Windows 上安装到中文/非 ASCII 路径时无法启动的问题（`gateway.cmd` 编码冲突导致计划任务静默失败）。

## 问题描述

### 症状
- `openclaw gateway start` / `openclaw gateway restart` 报告成功（计划任务返回码 0），但 `http://127.0.0.1:18789` 一直连不上（`ECONNREFUSED`）
- 重启电脑后网关无法自动恢复，Control UI / WebChat 全部断连
- 手动运行 `gateway.cmd` 报错：

```
'E:\灏忛緳铏綷node.exe' 不是内部或外部命令，也不是可运行的程序
```

### 根因
1. **Node.js 安装在中文路径**（例如 `E:\小龙虾\node.exe`）
2. OpenClaw 生成启动脚本 `gateway.cmd` 时以 **UTF-8 编码** 写入该路径
3. Windows `cmd.exe` 默认按系统 ANSI 代码页（中文系统为 **GBK/936**）解析 `.cmd` 文件
4. UTF-8 编码的 `小龙虾` 被 GBK 解码成乱码 `灏忛緳铏` → 找不到 node.exe → 网关静默启动失败
5. **加剧因素**：`openclaw gateway start` 每次检测到 CLI 版本差异都会"修复"并**整文件重写** `gateway.cmd`，把中文路径写回去——手动修复会被反复覆盖，问题反复发作

### 影响
- 仅影响 Windows 平台 + 非 ASCII 安装路径的组合
- 计划任务 `LastTaskResult=0` 但网关从未真正启动，排查困难

## 修复方案

### 核心思路：消除启动链路上的中文路径

```
修复前: 计划任务 → gateway.vbs → gateway.cmd(UTF-8中文路径) → ❌ cmd按GBK解析乱码
修复后: 计划任务 → gateway.vbs(先自动修复) → gateway.cmd(ASCII junction路径) → ✅
```

### 1. 创建 ASCII Junction（目录联接）

用纯 ASCII 路径指向中文目录，两种编码下都安全：

```powershell
mklink /J C:\Users\<你>\.openclaw\nodejs-link E:\小龙虾
# 验证
C:\Users\<你>\.openclaw\nodejs-link\node.exe --version   # v24.18.0
```

### 2. gateway.cmd 改用 ASCII 路径

启动脚本里的 node 路径从 `E:\小龙虾\node.exe` 改为：

```
C:\Users\<你>\.openclaw\nodejs-link\node.exe
```

### 3. 自愈保护（防 openclaw 覆盖）

`openclaw gateway start` 每次会重写 `gateway.cmd`（写回中文路径）并把计划任务重置回 vbs。因此：

- 计划任务的 Execute 固定指向 **gateway.vbs**（ASCII 编码，openclaw 不修改它）
- `gateway.vbs` 启动时先运行 `fix-gateway-cmd.ps1`：检测 `gateway.cmd` 是否被污染，若存在非 ASCII 的 node 路径则自动替换回 junction 路径（兼容 UTF-8 中文与 GBK 乱码两种形态）
- 修复完成后才启动网关

**效果**：即使以后手动运行 `openclaw gateway start` 把脚本覆盖坏，**下次开机自启时也会自动修复**，问题不再复发。

## 文件说明

| 文件 | 作用 |
|---|---|
| `fix-gateway-cmd.ps1` | 自动修复脚本：检测并替换 `gateway.cmd` 中被污染的 node 路径 |
| `gateway.vbs` | 保护版启动器：先修复，后启动（计划任务入口） |
| `gateway.cmd`（不在仓库中） | 由 `install.ps1` 生成到 `%USERPROFILE%\.openclaw\` 的启动脚本（ASCII junction 路径） |
| `install.ps1` | 一键安装：创建 junction + 写入脚本 + 注册计划任务 |

## 使用方法

```powershell
# 1. 以管理员/普通用户运行（junction 不需要管理员）
powershell -ExecutionPolicy Bypass -File install.ps1

# 2. 验证
openclaw gateway status        # 应显示 reachable
# 浏览器打开 http://127.0.0.1:18789
```

### 手动修复（不跑安装脚本）

```powershell
# 创建 junction
mklink /J C:\Users\<你>\.openclaw\nodejs-link E:\小龙虾

# 修复 gateway.cmd（如果存在中文路径）
powershell -File C:\Users\<你>\.openclaw\fix-gateway-cmd.ps1

# 确保计划任务指向保护版 vbs
```

## 验证结果

| 场景 | 结果 |
|---|---|
| 手动运行修复后的 gateway.cmd | ✅ 网关正常启动（HTTP server listening） |
| 污染 gateway.cmd（模拟 openclaw 覆盖）→ 运行 vbs | ✅ 自动修复 + 网关启动 HTTP 200 |
| 杀进程 → 触发计划任务 | ✅ 网关恢复 HTTP 200 |
| 网关健康检查 | ✅ `Gateway Health: OK` |

## 其他踩坑记录（WSL 方案，已放弃）

尝试过的 WSL 网关方案（systemd 自启）因以下原因放弃，留档备查：

1. PowerShell → WSL 传引号/heredoc 会被吃 → 需写 `.sh` 文件再 `bash /mnt/c/...` 执行
2. 脚本以 root 跑会污染配置属主导致 exit 78 → 需 `sudo chown -R`
3. 环境变量用 `OPENCLAW_CONFIG_PATH` + `OPENCLAW_STATE_DIR`（不是 `CONFIG_DIR`）
4. WSL 实例不随 Windows 开机自动启动 → 需额外计划任务

## License

MIT
