# Claude Code 工作流编排系统

基于 Vue Flow 的 Claude Code 工作流可视化系统。当 Claude Code 开始执行任务时，会自动编排工作流，等待用户确认后，在页面上实时显示每个步骤的执行进度。

## 功能特性

- **自动编排**: Claude Code 自动将任务拆解为工作流步骤
- **可视化编辑**: 使用 Vue Flow 拖拽界面审查和修改工作流
- **用户确认**: 执行前需要用户审批，可调整工作流
- **实时进度**: 通过 SSE 实时推送节点状态变更（等待 → 进行中 → 已完成）
- **暗色主题**: Catppuccin 风格 UI，带动画状态指示器

## 系统架构

```
┌──────────────┐    HTTP/SSE     ┌──────────────┐    Vue Flow    ┌──────────────┐
│  Claude Code │ ◄───────────── │   后端服务    │ ◄───────────── │   前端页面    │
│  (Skill)     │   curl 命令     │  (FastAPI)   │   SSE 推送     │  (Vue 3)     │
└──────────────┘                └──────────────┘               └──────────────┘
    端口 9800                        端口 5173
```

## 环境要求

- Python 3.9+
- Node.js 18+
- npm
- Claude Code CLI

## 安装步骤

### 1. 进入项目目录

```bash
cd /path/to/cc_work
```

### 2. 安装后端依赖

```bash
cd backend
pip3 install -r requirements.txt
```

### 3. 安装前端依赖

```bash
cd ../frontend
npm install
```

## 启动服务

### 方式一：一键启动（推荐）

```bash
./start.sh
```

自动启动后端（端口 9800）和前端（端口 5173）。

### 方式二：手动启动

**终端 1 - 后端：**
```bash
cd backend
python3 app.py
```

**终端 2 - 前端：**
```bash
cd frontend
npx vite --host
```

### 验证服务是否正常运行

```bash
# 检查后端
curl http://localhost:9800/api/health

# 在浏览器中打开前端
open http://localhost:5173
```

## 安装 Skill

Skill 文件位于 `.claude/skills/workflow.md`。Claude Code 会自动发现 `.claude/skills/` 目录下的所有 skill。

验证 skill 是否已安装：

```bash
ls -la .claude/skills/workflow.md
```

无需额外安装步骤 — Claude Code 在此项目目录下启动时会自动加载该 skill。

## 使用方法

### 自动使用

当你给 Claude Code 分配一个多步骤任务时，它会自动：

1. **规划工作流** — 将任务拆解为逻辑步骤
2. **创建工作流** — 通过 API 提交工作流图
3. **页面展示** — 工作流显示在 http://localhost:5173
4. **等待确认** — Claude Code 轮询等待你点击"确认工作流"
5. **执行并更新** — 每个步骤执行时，节点状态实时更新

### 使用示例

```
你: 创建一个带有用户认证、数据库模型和单元测试的 REST API

Claude Code:
  [创建包含 4 个节点的工作流]
  → 步骤 1: 设计数据库模型
  → 步骤 2: 创建 API 路由
  → 步骤 3: 实现用户认证
  → 步骤 4: 编写单元测试

  [在 UI 上等待你确认]

  [确认后，逐步执行并实时更新状态]
```

### 手动调用 Skill

你可以明确要求 Claude Code 使用工作流 skill：

```
使用 workflow skill 来规划和执行："用 React 和 FastAPI 构建一个待办应用"
```

### 工作流生命周期

| 状态 | 说明 |
|------|------|
| `pending_user_confirm` | 工作流已创建，等待用户审查 |
| `confirmed` | 用户已确认，准备执行 |
| `running` | Claude Code 正在执行步骤 |
| `completed` | 所有步骤执行完成 |
| `failed` | 一个或多个步骤失败 |

### 节点状态

| 状态 | 图标 | 视觉效果 |
|------|------|----------|
| `pending` | ⏳ | 灰色边框 |
| `in_progress` | ⚡ | 蓝色边框 + 脉冲发光动画 |
| `completed` | ✅ | 绿色边框 |
| `failed` | ❌ | 红色边框 |
| `skipped` | ⏭️ | 暗淡边框 |

## 实现原理

### Claude Code 如何等待用户在页面确认

系统使用**轮询模式**实现 Claude Code 与浏览器 UI 之间的同步。Claude Code 无法直接接收来自网页的回调，因此通过轮询后端 API 来检测状态变化。

```
Claude Code                    后端 API                      浏览器 UI
    │                              │                            │
    │  POST /api/workflows         │                            │
    │  (创建工作流)                │                            │
    │─────────────────────────────>│                            │
    │                              │  SSE: workflow_created     │
    │                              │───────────────────────────>│
    │                              │                            │
    │                              │       [用户在页面审查工作流]
    │                              │                            │
    │  GET /api/workflows/:id      │                            │
    │  (每 5 秒轮询一次状态)       │                            │
    │─────────────────────────────>│                            │
    │  { status: "pending_..." }   │                            │
    │<─────────────────────────────│                            │
    │                              │                            │
    │  GET /api/workflows/:id      │       POST /confirm        │
    │  (再次轮询)                  │<───────────────────────────│
    │─────────────────────────────>│                            │
    │  { status: "confirmed" }     │  SSE: workflow_confirmed   │
    │<─────────────────────────────│───────────────────────────>│
    │                              │                            │
    │  [开始执行任务]              │                            │
```

**核心代码 (`.claude/skills/workflow.md`)：**

```bash
# Claude Code 每 5-10 秒轮询此接口
curl -s http://localhost:9800/api/workflows/$WF_ID | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['status'])"
```

轮询循环持续进行，直到 `status` 从 `pending_user_confirm` 变为 `confirmed`。如果用户在对话中说"直接开始吧"，Claude Code 会跳过轮询直接执行。

**为什么用轮询而不是 WebSocket？**

Claude Code 通过 Bash 工具执行 shell 命令 — 它无法维持持久连接。使用 `curl` 轮询是在 Claude Code 执行模型下最简单、最可靠的方案。

---

### Claude Code 如何实时反馈任务进度

进度反馈采用 **HTTP POST → 后端 → SSE 推送** 的模式。Claude Code 调用 API 更新节点状态，后端通过 Server-Sent Events 将变更广播给所有已连接的浏览器。

```
Claude Code                    后端 API                      浏览器 UI
    │                              │                            │
    │  [开始处理 node_1]           │                            │
    │                              │                            │
    │  POST /nodes/n1/status       │                            │
    │  { status: "in_progress",    │                            │
    │    detail: "正在写代码..." }  │                            │
    │─────────────────────────────>│                            │
    │                              │  SSE: node_status_changed  │
    │                              │  { node_id: "n1",          │
    │                              │    status: "in_progress" } │
    │                              │───────────────────────────>│
    │                              │                            │
    │                              │    [节点变为蓝色，显示脉冲动画]
    │                              │    [显示 "正在写代码..."    ]
    │                              │                            │
    │  [完成 node_1]               │                            │
    │                              │                            │
    │  POST /nodes/n1/status       │                            │
    │  { status: "completed",      │                            │
    │    detail: "创建了 5 个文件" }│                            │
    │─────────────────────────────>│                            │
    │                              │  SSE: node_status_changed  │
    │                              │  { node_id: "n1",          │
    │                              │    status: "completed" }   │
    │                              │───────────────────────────>│
    │                              │                            │
    │                              │    [节点变为绿色，显示 ✅  ]
```

**核心代码 (`.claude/skills/workflow.md`)：**

```bash
# 标记节点为进行中
curl -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/node_1/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "in_progress", "detail": "正在分析需求..."}'

# 标记节点为已完成
curl -X POST http://localhost:9800/api/workflows/$WF_ID/nodes/node_1/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "completed", "detail": "创建了 3 个文件，共 150 行"}'
```

**后端 SSE 广播 (`backend/app.py`)：**

```python
async def _broadcast(workflow_id: str, event: str, data: dict):
    msg = {"event": event, "data": data}
    for queue in _subscribers.get(workflow_id, []):
        await queue.put(msg)
```

**前端 SSE 监听 (`frontend/src/App.vue`)：**

```javascript
es.addEventListener('node_status_changed', (e) => {
  const data = JSON.parse(e.data)
  // 创建新的数组引用以触发 Vue 响应式更新
  nodes.value = nodes.value.map(n => {
    if (n.id === data.node_id) {
      return { ...n, data: { ...n.data, status: data.status, detail: data.detail } }
    }
    return n
  })
})
```

### 为什么用 SSE 而不是 WebSocket？

- **SSE 是单向通信** — 完美适配服务端到客户端的推送场景，这正是我们需要的
- **SSE 自动重连** — 浏览器在连接断开时会自动重新连接
- **实现更简单** — 无需 WebSocket 握手，无需协议升级
- **兼容 HTTP/1.1** — 可正常穿越代理和负载均衡器

### 完整数据流

```
┌─────────────────────────────────────────────────────────────────────┐
│                          完整数据流                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Claude Code 创建工作流                                          │
│     curl POST → 后端存储工作流 → SSE 推送到浏览器                    │
│                                                                     │
│  2. 用户审查并确认                                                  │
│     浏览器 POST /confirm → 后端更新状态                             │
│     → SSE 推送 "confirmed" 到浏览器                                 │
│                                                                     │
│  3. Claude Code 轮询检测到确认                                      │
│     curl GET → 读取到 status: "confirmed" → 开始执行                │
│                                                                     │
│  4. Claude Code 更新进度                                            │
│     curl POST /nodes/:id/status → 后端存储状态                      │
│     → SSE 推送 "node_status_changed" 到浏览器                       │
│                                                                     │
│  5. 浏览器接收 SSE 并更新 Vue Flow                                  │
│     EventSource 监听器 → nodes.value = nodes.map(...)               │
│     → Vue 响应式触发重渲染 → CSS 动画播放                           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## API 接口

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/workflows` | 创建工作流 |
| `GET` | `/api/workflows` | 获取所有工作流 |
| `GET` | `/api/workflows/:id` | 获取指定工作流 |
| `PUT` | `/api/workflows/:id` | 更新工作流 |
| `DELETE` | `/api/workflows/:id` | 删除工作流 |
| `POST` | `/api/workflows/:id/confirm` | 用户确认工作流 |
| `POST` | `/api/workflows/:id/start` | 开始执行 |
| `POST` | `/api/workflows/:id/nodes/:nodeId/status` | 更新节点进度 |
| `GET` | `/api/workflows/:id/events` | SSE 事件流（单个工作流） |
| `GET` | `/api/events` | SSE 事件流（全局） |
| `GET` | `/api/health` | 健康检查 |

## 常见问题

### SSE 不显示实时更新

- 打开浏览器控制台（F12）查看是否有 `[SSE]` 日志
- 确认后端正在运行：`curl http://localhost:9800/api/health`
- 尝试直连后端：在 App.vue 中设置 `API = 'http://localhost:9800/api'`

### 前端页面无法加载

- 在 frontend 目录下执行 `npm install`
- 检查端口 5173 是否被占用：`lsof -i:5173`

### 后端报错

- 查看运行 `python3 app.py` 的终端输出
- 确认 Python 依赖已安装：`pip3 install -r requirements.txt`

### 工作流已创建但页面看不到

- 确认前端和后端都已启动
- 检查浏览器是否访问了 http://localhost:5173
- 工作流会显示在左侧边栏，需要点击选中才能查看详情

## 项目结构

```
cc_work/
├── backend/
│   ├── app.py              # FastAPI 服务（REST + SSE）
│   ├── models.py           # Pydantic 数据模型
│   └── requirements.txt    # Python 依赖
├── frontend/
│   ├── src/
│   │   ├── App.vue         # 主页面（Vue Flow）
│   │   ├── components/
│   │   │   └── WorkflowNode.vue  # 自定义节点组件
│   │   └── main.js         # 入口文件
│   ├── index.html
│   ├── package.json        # Node.js 依赖
│   └── vite.config.js      # Vite 配置
├── .claude/skills/
│   └── workflow.md         # Claude Code Skill 定义
├── CLAUDE.md               # 项目上下文文件
├── README.md               # 英文文档
├── README_zh.md            # 中文文档
└── start.sh                # 一键启动脚本
```
