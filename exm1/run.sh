#!/bin/bash

# 实验名列表
EXPERIMENTS=("beeqos" "htb" "no-shaper")
# EXPERIMENTS=("no-shaper")
# EXPERIMENTS=("cilium")

# 循环次数
NUM_RUNS=10

for cur in "${EXPERIMENTS[@]}"; do
    for id in $(seq 0 $((NUM_RUNS-1))); do
        echo "[INFO] Running experiment: $cur, id=$id"

        if [[ "$cur" == "beeqos" && "$id" -eq 0 ]]; then
            cd .. && bash setup_beeqos_after_calico.sh && cd -
        fi

        if [[ "$cur" == "htb" && "$id" -eq 0 ]]; then
            ssh root@10.102.0.235 'sudo bash -s' < ./set_htb.sh
        fi

        if [[ "$cur" == "cilium" ]]; then
            kubectl apply -f yamls/server_cilium.yaml
            kubectl apply -f yamls/client_cilium.yaml
        else 
            kubectl apply -f yamls/server.yaml
            kubectl apply -f yamls/client.yaml
        fi

        echo "[INFO] 等待 Pod 启动并就绪..."
        pods=("client-1" "client-1" "client-1" "server-1" "server-2" "server-3")
        for pod in "${pods[@]}"; do
        echo "  -> 等待 $pod Ready..."
        kubectl wait --for=condition=ready pod/"$pod" --timeout=60s
        done
        echo "[INFO] 所有 Pod 已经就绪 ✅"


        clients=("client-1" "client-2" "client-3")
        if [[ "$cur" == "cilium" ]]; then
            SERVER_IP1=$(kubectl get pod server-1 -o jsonpath='{.status.podIP}')
            SERVER_IP2=$(kubectl get pod server-2 -o jsonpath='{.status.podIP}')
            SERVER_IP3=$(kubectl get pod server-3 -o jsonpath='{.status.podIP}')
            targets_bw=($SERVER_IP1 $SERVER_IP2 $SERVER_IP3)
            targets_lat=($SERVER_IP1 $SERVER_IP2 $SERVER_IP3)
        else
            targets_bw=("10.255.24.11" "10.255.24.12" "10.255.24.13")
            targets_lat=("10.255.24.11" "10.255.24.12" "10.255.24.13")
        fi       

        # 初始化 logs 目录
        for c in "${clients[@]}"; do
            kubectl exec $c -- bash -c "mkdir -p logs && rm -rf logs/*"
        done

        # 启动 throughput 测试
        for i in "${!clients[@]}"; do
            echo "BW test on", $i, ${clients[$i]}
            kubectl exec "${clients[$i]}" -- bash -c \
                "sockperf throughput --tcp -i ${targets_bw[$i]} -p 5201 -t 60 -m 1472 > logs/bw.log 2>&1" &
        done

        wait

        # 启动 latency 测试
        for i in "${!clients[@]}"; do
            echo "LAT test on", $i, ${clients[$i]}
            kubectl exec "${clients[$i]}" -- bash -c \
                "sockperf throughput --tcp -i ${targets_bw[$i]} -p 5201 -t 60 -m 1472 > /tmp/bw.log 2>&1" &
            kubectl exec "${clients[$i]}" -- bash -c \
                "sockperf under-load --tcp -i ${targets_lat[$i]} -p 5201 -t 60 -m 1472 > logs/lat.log 2>&1" &
        done

        # 等待所有后台任务完成
        wait

        # 拷贝日志到本地
        for i in "${!clients[@]}"; do
            mkdir -p logs/$cur/$id/c$((i+1))
            kubectl cp "${clients[$i]}":logs logs/$cur/$id/c$((i+1))
        done

        # kubectl delete -f yamls/server.yaml --grace-period=0 --force
        # kubectl delete -f yamls/client.yaml --grace-period=0 --force

        if [[ "$cur" == "beeqos" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            cd .. && bash remove_beeqos_after_calico.sh && cd -
        fi

        if [[ "$cur" == "htb" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            ssh root@10.102.0.235 'sudo bash -s' < ./unset_htb.sh
        fi

        if [[ "$cur" == "cilium" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            kubectl delete -f yamls/server_cilium.yaml --grace-period=0 --force
            kubectl delete -f yamls/client_cilium.yaml --grace-period=0 --force
        fi

        echo "[INFO] Logs moved to logs/dash_exm/$cur/$id"
    done
done


