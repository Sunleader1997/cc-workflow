#!/bin/bash
# 运行环境检查与自动修复脚本
# 确保 build.sh 能正常运行

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0
FIXED=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

check_fix() {
    echo -e "${BLUE}→${NC} $1"
}

echo "=== Claude Code Workflow Orchestrator - 环境检查 ==="
echo ""

# ───────────────────────────────────────────────
# 1. 检查 Node.js 和 npm
# ───────────────────────────────────────────────
echo "[1/6] 检查 Node.js 环境..."

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    check_pass "Node.js 已安装: $NODE_VERSION"
else
    check_fail "Node.js 未安装"
    check_fix "请安装 Node.js (建议 v18+): https://nodejs.org/"
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    check_pass "npm 已安装: v$NPM_VERSION"
else
    check_fail "npm 未安装"
    check_fix "npm 通常随 Node.js 一起安装"
fi

echo ""

# ───────────────────────────────────────────────
# 2. 检查 Python3 和 pip3
# ───────────────────────────────────────────────
echo "[2/6] 检查 Python 环境..."

PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    PYTHON_VERSION=$(python3 --version)
    check_pass "Python3 已安装: $PYTHON_VERSION"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
    PYTHON_VERSION=$(python --version)
    check_pass "Python 已安装: $PYTHON_VERSION"
else
    check_fail "Python3 未安装"
    check_fix "请安装 Python3 (建议 3.9+): https://python.org/"
fi

if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
    check_pass "pip3 已安装"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
    check_pass "pip 已安装"
else
    check_fail "pip3/pip 未安装"
    check_fix "请安装 pip: python -m ensurepip --upgrade"
fi

echo ""

# ───────────────────────────────────────────────
# 3. 检查项目文件结构
# ───────────────────────────────────────────────
echo "[3/6] 检查项目文件结构..."

if [ -f "$SCRIPT_DIR/frontend/package.json" ]; then
    check_pass "frontend/package.json 存在"
else
    check_fail "frontend/package.json 不存在"
fi

if [ -d "$SCRIPT_DIR/frontend" ]; then
    check_pass "frontend/ 目录存在"
else
    check_fail "frontend/ 目录不存在"
fi

if [ -f "$SCRIPT_DIR/backend/app.py" ]; then
    check_pass "backend/app.py 存在"
else
    check_fail "backend/app.py 不存在"
fi

if [ -f "$SCRIPT_DIR/backend/models.py" ]; then
    check_pass "backend/models.py 存在"
else
    check_warn "backend/models.py 不存在 (app.py 依赖此文件)"
fi

if [ -f "$SCRIPT_DIR/build.sh" ]; then
    check_pass "build.sh 存在"
else
    check_fail "build.sh 不存在"
fi

echo ""

# ───────────────────────────────────────────────
# 4. 检查并自动修复 Python 依赖
# ───────────────────────────────────────────────
echo "[4/6] 检查 Python 依赖..."

# 依赖列表: pip包名 对应 Python导入名
PIP_NAMES=("fastapi" "uvicorn" "sse-starlette" "pydantic" "pyinstaller")
IMPORT_NAMES=("fastapi" "uvicorn" "sse_starlette" "pydantic" "PyInstaller")

for i in "${!PIP_NAMES[@]}"; do
    pip_name="${PIP_NAMES[$i]}"
    import_name="${IMPORT_NAMES[$i]}"
    if $PYTHON_CMD -c "import $import_name" 2>/dev/null; then
        check_pass "Python 依赖已安装: $pip_name"
    else
        check_warn "Python 依赖缺失: $pip_name"
        check_fix "尝试自动安装 $pip_name..."
        if $PIP_CMD install "$pip_name" -q 2>/dev/null; then
            check_pass "已自动安装: $pip_name"
            ((FIXED++))
        else
            check_fail "自动安装失败: $pip_name，请手动运行: $PIP_CMD install $pip_name"
        fi
    fi
done

echo ""

# ───────────────────────────────────────────────
# 5. 检查前端依赖 (node_modules)
# ───────────────────────────────────────────────
echo "[5/6] 检查前端依赖..."

if [ -d "$SCRIPT_DIR/frontend/node_modules" ]; then
    check_pass "frontend/node_modules 已存在"
else
    check_warn "frontend/node_modules 不存在"
    check_fix "尝试自动安装前端依赖..."
    cd "$SCRIPT_DIR/frontend"
    if npm install 2>/dev/null; then
        check_pass "前端依赖已自动安装"
        ((FIXED++))
    else
        check_fail "前端依赖安装失败，请手动运行: cd frontend && npm install"
    fi
fi

echo ""

# ───────────────────────────────────────────────
# 6. 检查端口占用 (build.sh 构建的可执行文件运行在 9800)
# ───────────────────────────────────────────────
echo "[6/6] 检查端口占用..."

if lsof -Pi :9800 -sTCP:LISTEN -t >/dev/null 2>&1; then
    PID=$(lsof -Pi :9800 -sTCP:LISTEN -t)
    check_warn "端口 9800 已被占用 (PID: $PID)"
    check_fix "运行时可使用其他端口，或先停止占用进程"
else
    check_pass "端口 9800 可用"
fi

echo ""

# ───────────────────────────────────────────────
# 汇总
# ───────────────────────────────────────────────
echo "======================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有检查通过，环境就绪！${NC}"
    echo ""
    echo "可以运行: ./build.sh"
    exit 0
elif [ $ERRORS -eq 0 ] && [ $WARNINGS -gt 0 ]; then
    if [ $FIXED -gt 0 ]; then
        echo -e "${GREEN}✓ 环境已修复，可以运行 build.sh${NC}"
        echo -e "  自动修复: $FIXED 项"
    else
        echo -e "${YELLOW}⚠ 有警告但不影响构建${NC}"
    fi
    echo ""
    echo "可以运行: ./build.sh"
    exit 0
else
    echo -e "${RED}✗ 环境检查未通过，请修复上述错误${NC}"
    echo -e "  错误: $ERRORS"
    echo -e "  警告: $WARNINGS"
    if [ $FIXED -gt 0 ]; then
        echo -e "  已自动修复: $FIXED 项"
    fi
    echo ""
    echo "修复后重新运行: ./check.sh"
    exit 1
fi
