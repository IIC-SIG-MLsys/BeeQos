#!/bin/bash

# ===================================================================
# 自动化构建并部署 bwm 镜像
# 使用 ctr（containerd）替代 docker
# 步骤：
#   1. 清理本地旧镜像（ctr + docker）
#   2. 构建新镜像（make all）
#   3. 导出镜像为 tar
#   4. 本地导入到 containerd（k8s.io）
#   5. 推送到远程
#   6. 远程导入到 containerd
#   7. 验证本地和远程
# ===================================================================

# 使用containerd搭建k8s集群，使用docker导出镜像，ctr导入
# 配置免密登陆远程服务器

# -------------------------------
# 配置参数
# -------------------------------
IMAGE_TAG="f01cb71"
IMAGE_REF="docker.io/library/bwm:${IMAGE_TAG}"
REMOTE_USER="liujinyao" # k8s user
REMOTE_ROOT="root"
REMOTE_IP="10.102.0.235"
REMOTE_DIR="/home/${REMOTE_USER}/k8s"
TAR_FILE="bwm.tar"
NAMESPACE="k8s.io"

# -------------------------------
# 颜色定义
# -------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() { echo -e "[${GREEN}✓${NC}] $1"; }
failure() { echo -e "[${RED}✗${NC}] $1"; }
info()    { echo -e "[${YELLOW}i${NC}] $1"; }
step() {
  local desc="$1"; shift
  echo -n "[${YELLOW}→${NC}] $desc... "
  if "$@" > /tmp/ctr_deploy.log 2>&1; then
    success "OK"
    return 0
  else
    failure "FAILED"
    cat /tmp/ctr_deploy.log >&2
    rm -f /tmp/ctr_deploy.log
    return 1
  fi
  rm -f /tmp/ctr_deploy.log
}

# -------------------------------
# 开始执行
# -------------------------------
echo -e "${GREEN}🚀 开始部署 bwm 镜像（使用 ctr）${NC}\n"

# 1. 停止并清理旧容器（可选）
info "清理本地旧镜像引用: $IMAGE_REF"

# 删除本地 ctr 镜像（忽略错误，可能不存在）
ctr -n "$NAMESPACE" i rm "$IMAGE_REF" 2>/dev/null || true

# 如果你还用了 Docker，也清理
if command -v docker &> /dev/null; then
  docker rmi "$IMAGE_REF" 2>/dev/null || true
fi
success "旧镜像已清理（如存在）"

cd bwm
# 2. 构建镜像（假设 make all 生成镜像）
step "构建镜像（make all）" make all
cd ..

# 3. 检查镜像是否生成（通过 docker 或 build artifacts）
#    如果 make all 不生成镜像，请替换为 buildah/buildkit 等
#    这里假设 make all 会生成 docker 镜像
if ! (docker image inspect "$IMAGE_REF" &>/dev/null || ctr -n "$NAMESPACE" i inspect "$IMAGE_REF" &>/dev/null); then
  failure "构建完成后未找到镜像 $IMAGE_REF"
  exit 1
fi
success "镜像构建完成"

# 4. 导出镜像为 tar
step "导出镜像为 $TAR_FILE" \
  docker save "$IMAGE_REF" -o "$TAR_FILE"

# 5. 本地导入到 containerd
step "本地导入镜像到 ctr ($NAMESPACE)" \
  sudo ctr -n "$NAMESPACE" i import "$TAR_FILE"

# 6. 验证本地导入
info "验证本地镜像..."
if sudo ctr -n "$NAMESPACE" i ls | grep -q "bwm.*${IMAGE_TAG}"; then
  success "✅ 本地镜像导入成功"
else
  failure "❌ 本地未找到 bwm:${IMAGE_TAG}"
  exit 1
fi

# 7. 复制到远程
step "复制 $TAR_FILE 到 ${REMOTE_USER}@${REMOTE_IP}:${REMOTE_DIR}" \
  scp "$TAR_FILE" "${REMOTE_USER}@${REMOTE_IP}:${REMOTE_DIR}/"

# 8. 远程删除旧镜像（root 执行）
step "远程删除旧镜像" \
  ssh "${REMOTE_ROOT}@${REMOTE_IP}" "ctr -n $NAMESPACE i rm $IMAGE_REF" || true

# 9. 远程导入
step "远程导入镜像" \
  ssh "${REMOTE_ROOT}@${REMOTE_IP}" "cd ${REMOTE_DIR} && ctr -n $NAMESPACE i import ${TAR_FILE}"

# 10. 验证远程
info "验证远程镜像..."
if ssh "${REMOTE_ROOT}@${REMOTE_IP}" "ctr -n $NAMESPACE i ls | grep -q 'bwm.*${IMAGE_TAG}'"; then
  success "✅ 远程镜像导入成功"
else
  failure "❌ 远程未找到 bwm:${IMAGE_TAG}"
  exit 1
fi

# -------------------------------
# 最终状态展示
# -------------------------------
echo -e "\n${GREEN}🎉 部署完成！本地和远程镜像均已更新${NC}"

echo -e "\n📦 本地镜像状态："
sudo ctr -n "$NAMESPACE" i ls | grep bwm

echo -e "\n📦 远程镜像状态："
ssh "${REMOTE_ROOT}@${REMOTE_IP}" "ctr -n $NAMESPACE i ls | grep bwm"