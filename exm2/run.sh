#!/bin/bash

# 实验名列表
EXPERIMENTS=("beeqos" "htb" "no-shaper")
# EXPERIMENTS=("htb" "no-shaper")
# EXPERIMENTS=("cilium")

# 循环次数
NUM_RUNS=10

for cur in "${EXPERIMENTS[@]}"; do
    for id in $(seq 0 $((NUM_RUNS-1))); do
        echo "[INFO] Running experiment: $cur, id=$id"

        # 初始化操作
        if [[ "$cur" == "beeqos" && "$id" -eq 0 ]]; then
            cd .. && bash setup_beeqos_after_calico.sh && cd -
        fi

        if [[ "$cur" == "htb" && "$id" -eq 0 ]]; then
            ssh root@10.102.0.235 'sudo bash -s' < ./set_htb.sh
        fi

        if [[ "$cur" == "cilium" ]]; then
            kubectl apply -f yamls/iperf-server-cilium.yaml
            kubectl apply -f yamls/iperf-client-cilium.yaml
        else 
            kubectl apply -f yamls/iperf-server.yaml
            kubectl apply -f yamls/iperf-client.yaml
        fi

        echo "[INFO] 等待 Pod 启动并就绪..."
        pods=("exm2-client" "exm2-server-high-1" "exm2-server-high-2" "exm2-server-low")
        for pod in "${pods[@]}"; do
        echo "  -> 等待 $pod Ready..."
        kubectl wait --for=condition=ready pod/"$pod" --timeout=60s
        done
        echo "[INFO] 所有 Pod 已经就绪 ✅"

        bash run_iperf3.sh

        mkdir -p logs/bw/$cur/$id

        mv logs/*.log logs/bw/$cur/$id/

        # kubectl delete -f yamls/iperf-server.yaml
        # kubectl delete -f yamls/iperf-client.yaml

        if [[ "$cur" == "beeqos" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            cd .. && bash remove_beeqos_after_calico.sh && cd -
        fi

        if [[ "$cur" == "htb" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            ssh root@10.102.0.235 'sudo bash -s' < ./unset_htb.sh
        fi

        if [[ "$cur" == "cilium" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            kubectl delete -f yamls/iperf-server-cilium.yaml --grace-period=0 --force
            kubectl delete -f yamls/iperf-client-cilium.yaml --grace-period=0 --force
        fi

        echo "[INFO] Logs moved to logs/bw/$cur/$id"
    done
done
