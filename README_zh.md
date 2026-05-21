# Claude Code 工作流编排系统

基于 Vue Flow 的 Claude Code 工作流可视化系统。当 Claude Code 开始执行任务时，会自动编排工作流，等待用户确认后，在页面上实时显示每个步骤的执行进度。

## 快速开始

```bash
# 1. 安装依赖
cd backend && pip3 install -r requirements.txt && cd ..
cd frontend && npm install && cd ..

# 2. 启动服务
./start.sh

# 3. 打开浏览器
open http://localhost:5173
```

完成。当你给 Claude Code 分配多步骤任务时，它会自动使用工作流 skill。

---

## 环境要求

| 依赖 | 版本 | 检查命令 |
|------|------|----------|
| Python | 3.9+ | `python3 --version` |
| Node.js | 18+ | `node --version` |
| npm | 8+ | `npm --version` |
| Claude Code | 最新版 | `claude --version` |

## 安装步骤

### 第一步：进入项目目录

```bash
cd /path/to/cc_work
```

### 第二步：安装后端（Python/FastAPI）

```bash
cd backend
pip3 install -r requirements.txt
cd ..
```

安装内容：FastAPI、uvicorn、sse-starlette、pydantic。

### 第三步：安装前端（Vue 3/Vite）

```bash
cd frontend
npm install
cd ..
```

安装内容：Vue 3、Vue Flow、Vite 及相关包。

### 第四步：验证安装

```bash
# 检查后端依赖
python3 -c "import fastapi, uvicorn, sse_starlette; print('后端依赖 OK')"

# 检查前端依赖
ls frontend/node_modules/@vue-flow/core/package.json && echo "前端依赖 OK"
```

## 启动服务

### 方式一：一键启动（推荐）

```bash
./start.sh
```

此脚本会：
1. 终止占用 9800 和 5173 端口的已有进程
2. 在端口 9800 启动 FastAPI 后端
3. 在端口 5173 启动 Vite 前端
4. 显示两个服务的日志

按 `Ctrl+C` 停止所有服务。

### 方式二：手动启动（需要两个终端）

**终端 1 — 后端：**
```bash
cd backend
python3 app.py
```
输出：`Uvicorn running on http://0.0.0.0:9800`

**终端 2 — 前端：**
```bash
cd frontend
npx vite --host
```
输出：`Local: http://localhost:5173/`

### 验证服务是否正常运行

```bash
# 后端健康检查
curl http://localhost:9800/api/health
# 预期输出：{"status":"ok","workflows":0}

# 前端 — 在浏览器中打开
open http://localhost:5173
```

## 安装 Skill

Skill 文件已包含在项目中：`.claude/skills/workflow.md`。Claude Code 会自动发现 `.claude/skills/` 目录下的所有 skill，无需手动安装。

验证：
```bash
cat .claude/skills/workflow.md | head -5
```

当 Claude Code 在此项目目录下启动时，skill 会自动激活。

## 使用方法

### 工作流程

1. 你给 Claude Code 分配一个多步骤任务
2. Claude Code 创建工作流图并提交到 API
3. 工作流显示在 http://localhost:5173 供你审查
4. 你可以修改节点/边，然后点击 **"确认工作流"**
5. Claude Code 检测到确认后开始执行
6. 每个节点随工作进度实时更新状态

### 示例

```
你: 创建一个带有用户认证和测试的 REST API

Claude Code 自动执行：
  → 创建包含 4 个步骤的工作流
  → 在 UI 上展示
  → 等待你确认
  → 逐步执行并实时更新状态
```

### 节点状态说明

| 状态 | 图标 | 视觉效果 |
|------|------|----------|
| `pending` | ⏳ | 灰色边框 |
| `in_progress` | ⚡ | 蓝色边框 + 脉冲发光动画 |
| `completed` | ✅ | 绿色边框 |
| `failed` | ❌ | 红色边框 |

## 常见问题

### 端口被占用
```bash
# 终止占用 9800 和 5173 端口的进程
lsof -ti:9800 | xargs kill -9
lsof -ti:5173 | xargs kill -9
```

### 后端无法启动
```bash
# 安装 Python 依赖
pip3 install -r backend/requirements.txt

# 查看错误信息
cd backend && python3 app.py
```

### 前端无法启动
```bash
# 重新安装依赖
cd frontend && rm -rf node_modules && npm install
```

### SSE 不显示实时更新
- 打开浏览器控制台（F12）查看是否有 `[SSE]` 日志
- 确认后端正在运行：`curl http://localhost:9800/api/health`
- 需要在侧边栏选中工作流才能接收 SSE 事件

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
│   └── vite.config.js      # Vite 配置（含 API 代理）
├── .claude/skills/
│   └── workflow.md         # Claude Code Skill 定义
├── CLAUDE.md               # 项目上下文文件
├── README.md               # 英文文档
├── README_zh.md            # 中文文档
└── start.sh                # 一键启动脚本
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
| `POST` | `/api/workflows/:id/nodes/:nodeId/status` | 更新节点进度 |
| `GET` | `/api/workflows/:id/events` | SSE 事件流 |
| `GET` | `/api/health` | 健康检查 |
