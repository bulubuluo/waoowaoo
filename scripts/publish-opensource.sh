#!/bin/bash
# ============================================================
# 开源版本发布脚本
# - 首次发布：创建孤儿分支（无历史）
# - 后续发布：基于公开仓库历史追加 commit（用户可 git pull）
# 用法: bash scripts/publish-opensource.sh
# ============================================================

set -e

echo ""
echo "🚀 开始发布开源版本..."

# 确保当前在 main 分支，且工作区干净
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "❌ 请先切换到 main 分支再运行发布脚本"
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "❌ 工作区有未提交的改动，请先 commit 再发布"
  exit 1
fi

# 检查公开仓库是否已有历史
echo "🔍 检查公开仓库状态..."
git fetch public 2>/dev/null || true
PUBLIC_HAS_HISTORY=$(git ls-remote public main 2>/dev/null | wc -l | tr -d ' ')

if [ "$PUBLIC_HAS_HISTORY" = "0" ]; then
  # ========== 首次发布：孤儿分支 ==========
  echo "📦 首次发布，创建干净的孤儿分支..."
  git checkout --orphan release-public
  git add -A
else
  # ========== 后续发布：基于公开仓库历史追加 commit ==========
  echo "📦 增量发布，基于公开仓库历史追加 commit..."
  git checkout -b release-public public/main
  # 将当前 main 的所有文件覆盖进来
  git checkout main -- .
  git add -A
fi

# 从提交中移除不应公开的内容
echo "🧹 清理私有内容..."
git rm --cached .env -f 2>/dev/null || true                  # 本地 env（含真实配置）
git rm -r --cached .github/workflows/ 2>/dev/null || true    # CI 流水线（不对外）
git rm -r --cached .agent/ 2>/dev/null || true               # AI 工具目录
git rm -r --cached .artifacts/ 2>/dev/null || true           # AI 工具数据
git rm -r --cached .shared/ 2>/dev/null || true              # AI 工具数据

# 提交快照
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
git commit -m "release: opensource snapshot $TIMESTAMP" 2>/dev/null || {
  echo "ℹ️  无可提交的改动，版本已是最新"
  git checkout -f main
  git branch -D release-public 2>/dev/null || true
  exit 0
}
echo "✅ 快照 commit 已创建"

# 推送到公开仓库（首次强推，后续普通推送）
echo "⬆️  推送到公开仓库..."
if [ "$PUBLIC_HAS_HISTORY" = "0" ]; then
  git push public release-public:main --force
else
  git push public release-public:main
fi

echo ""
echo "=============================================="
echo "✅ 开源版本发布成功！"
echo "🔗 https://github.com/plotweaveAI/plotweave"
echo "=============================================="
echo ""

# 切回 main 分支，删除临时分支
git checkout -f main
git branch -D release-public

echo "🔙 已切回 main 分支，临时分支已清理"
echo ""
