# openclaw-lark-stream-enhancer

为 `@larksuite/openclaw-lark` 添加 **exec/命令实时输出** 和 **增强工具调用可视化** 的流式卡片增强补丁。

## ✨ 功能

基于 openclaw-lark (v2026.5.13+) 现有工具可视化基础架构，添加：

- **Exec 实时输出** — exec 命令的 stdout/stderr 流式显示在飞书卡片中
- **`onCommandOutput` hook** — 接入 OpenClaw 5.x 新增的命令输出事件
- **`onToolResult` / `onItemEvent` hook** — 工具结果监控兜底

> openclaw-lark v2026.5.13 已内置工具调用追踪和卡片渲染，但 `onCommandOutput` 等 5.x 新 hook 尚未接入。本补丁补全了这些。

## 📦 安装

```bash
# 1. 确保已安装最新 openclaw-lark
npm install -g @larksuite/openclaw-lark@latest

# 2. 应用补丁
bash apply.sh

# 3. 重启 Gateway
openclaw gateway restart
```

## ⚙️ 启用工具可视化

工具调用可视化通过 `/verbose` 模式控制（openclaw-lark 原生机制）：

```bash
# 临时启用（在飞书 DM/群聊中发送）
/verbose           # 显示工具调用状态
/verbose full      # 含工具结果详情

# 永久启用
openclaw config set agents.defaults.verboseDefault on
openclaw gateway restart
```

## 📄 修改文件

| 文件 | 改动 |
|------|------|
| `src/card/reply-dispatcher.js` | 接入 `onCommandOutput`、`onToolResult`、`onItemEvent` hook |
| `src/card/streaming-card-controller.js` | 新增 `onCommandOutput` 方法，追踪命令输出到 tool-use-trace-store |

## 🧹 卸载

```bash
# 重装 openclaw-lark 即可恢复
npm install -g @larksuite/openclaw-lark@latest
openclaw gateway restart
```
