#!/bin/bash
# 用法: ./distribute_cilium.sh <REMOTE_USER> <REMOTE_IP> <REMOTE_DIR>

set -e

# --------------------------
# 参数
# --------------------------
REMOTE_USER=$1
REMOTE_IP=$2
REMOTE_DIR=$3
NAMESPACE="k8s.io"

# --------------------------
# 参数校验
# --------------------------
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "错误: 缺少参数"
    echo "用法: $0 <REMOTE_USER> <REMOTE_IP> <REMOTE_DIR>"
    echo "示例: $0 liujinyao 10.102.0.235 /home/liujinyao/k8s"
    exit 1
fi

# 镜像列表
IMAGES=(
  "quay.io/cilium/cilium:v1.18.1"
  "quay.io/cilium/cilium-envoy:v1.34.4-1754895458-68cffdfa568b6b226d70a7ef81fc65dda3b890bf@sha256:247e908700012f7ef56f75908f8c965215c26a27762f296068645eb55450bda2"
)

for IMG in "${IMAGES[@]}"; do
    docker pull $IMG
done

# --------------------------
# 本地保存镜像为 tar
# --------------------------
echo "==> 导出镜像为 tar..."
for IMG in "${IMAGES[@]}"; do
    FILE_NAME=$(echo $IMG | sed 's|[:/]|-|g').tar
    echo "导出 $IMG -> $FILE_NAME"
    docker save -o "$FILE_NAME" "$IMG"
done

# --------------------------
# 传输镜像到远程节点
# --------------------------
echo "==> 拷贝镜像到远程节点 ${REMOTE_IP}:${REMOTE_DIR}"
ssh ${REMOTE_USER}@${REMOTE_IP} "mkdir -p ${REMOTE_DIR}"
for IMG in "${IMAGES[@]}"; do
    FILE_NAME=$(echo $IMG | sed 's|[:/]|-|g').tar
    scp "$FILE_NAME" "${REMOTE_USER}@${REMOTE_IP}:${REMOTE_DIR}/"
done

# --------------------------
# 在远程节点导入 containerd
# --------------------------
echo "==> 在远程节点导入 containerd..."
for IMG in "${IMAGES[@]}"; do
    FILE_NAME=$(echo $IMG | sed 's|[:/]|-|g').tar
    ssh ${REMOTE_USER}@${REMOTE_IP} "cd ${REMOTE_DIR} && sudo ctr -n ${NAMESPACE} i import ${FILE_NAME}"
done

# --------------------------
# 本地节点导入 containerd
# --------------------------
echo "==> 本地导入 containerd..."
for IMG in "${IMAGES[@]}"; do
    FILE_NAME=$(echo $IMG | sed 's|[:/]|-|g').tar
    sudo ctr -n ${NAMESPACE} i import "$FILE_NAME"
done

echo "==> 完成，镜像已导入 containerd"