#!/bin/bash
# cleanup-cilium-all.sh
# 清理本地和远程节点 (10.102.0.235) 的 Cilium 残留

REMOTE_HOST="10.102.0.235"
REMOTE_USER="root"

cleanup_node() {
    NODE=$1
    echo "============================"
    echo "[INFO] 开始清理节点: $NODE"

    ssh ${REMOTE_USER}@${NODE} bash -s <<EOF
        set -e
        echo "[INFO] 删除 CNI 配置"
        sudo rm -f /etc/cni/net.d/*cilium*.conf

        echo "[INFO] 删除 CNI 二进制"
        sudo rm -f /usr/local/bin/cilium*

        echo "[INFO] 删除 cilium socket"
        sudo rm -f /var/run/cilium/cilium.sock

        echo "[INFO] 清理 cilium 网卡"
        for dev in \$(ip link show | grep -E "cilium|lxc" | awk -F: '{print \$2}' | sed 's/@.*//' | tr -d ' '); do
            sudo ip link delete \$dev || true
        done

        echo "[INFO] 清理 cilium 路由 (proto bird)"
        sudo ip route flush proto bird || true

        echo "[INFO] 重启 kubelet"
        sudo systemctl restart kubelet

        echo "[INFO] 节点清理完成！"
EOF
}

# 本地执行清理
echo "[INFO] 开始清理本地节点"
bash -s <<EOF
    set -e
    echo "[INFO] 删除 CNI 配置"
    sudo rm -f /etc/cni/net.d/*cilium*.conf

    echo "[INFO] 删除 CNI 二进制"
    sudo rm -f /usr/local/bin/cilium*

    echo "[INFO] 删除 cilium socket"
    sudo rm -f /var/run/cilium/cilium.sock

    echo "[INFO] 清理 cilium 网卡"
    for dev in \$(ip link show | grep -E "cilium|lxc" | awk -F: '{print \$2}' | sed 's/@.*//' | tr -d ' '); do
        sudo ip link delete \$dev || true
    done

    echo "[INFO] 清理 cilium 路由 (proto bird)"
    sudo ip route flush proto bird || true

    echo "[INFO] 重启 kubelet"
    sudo systemctl restart kubelet

    echo "[INFO] 本地节点清理完成！"
EOF

# 远程执行清理
cleanup_node $REMOTE_HOST

echo "[INFO] 所有节点清理完成 ✅"