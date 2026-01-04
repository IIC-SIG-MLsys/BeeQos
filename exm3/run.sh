#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# 实验配置
# -----------------------------
# EXPERIMENTS=("beeqos" "htb" "no-shaper")
# EXPERIMENTS=("htb")
EXPERIMENTS=("cilium")
NUM_RUNS=10

SOCKPERF_PORT=5300         # sockperf server端口
IPERF_PORT=5201            # iperf server端口
DURATION=120               # 测试时长（秒）
OUTDIR="logs"

client="client-1"
servers=("server-1")

MAX_IPERF_STREAMS=2048  # 单个 iperf 进程最大并发流

# -----------------------------
# 开始实验
# -----------------------------
for cur in "${EXPERIMENTS[@]}"; do
    for id in $(seq 0 $((NUM_RUNS-1))); do
        echo "[INFO] Running experiment: $cur, id=$id"

        # -----------------------------
        # 限速策略
        # -----------------------------
        if [[ "$cur" == "beeqos" && "$id" -eq 0 ]]; then
            cd .. && bash setup_beeqos_after_calico.sh && cd -
        fi

        if [[ "$cur" == "htb" && "$id" -eq 0 ]]; then
            ssh root@10.102.0.235 'sudo bash -s' < ./set_htb.sh
        fi

        # -----------------------------
        # 启动 Pod
        # -----------------------------
        if [[ "$cur" == "cilium" ]]; then
            kubectl apply -f yamls/server_cilium.yaml
            kubectl apply -f yamls/client_cilium.yaml
        else 
            kubectl apply -f yamls/server.yaml
            kubectl apply -f yamls/client.yaml
        fi

        echo "[INFO] 等待 Pod 启动并就绪..."
        pods_to_wait=( "$client" "${servers[@]}" )
        for pod in "${pods_to_wait[@]}"; do
            echo "  -> 等待 $pod Ready..."
            kubectl wait --for=condition=ready pod/"$pod" --timeout=120s || \
                { echo "[WARN] 等待 $pod 超时，但继续执行"; }
        done
        echo "[INFO] 所有 Pod(尝试)就绪 ✅"

        # -----------------------------
        # 并发流列表
        # -----------------------------
        FS_LIST=(8 32 128 512 1024)
        SERVER_IP=$(kubectl get pod server-1 -o jsonpath='{.status.podIP}')   # sockperf server IP

        for total_fs in "${FS_LIST[@]}"; do
            echo "[INFO] 测试并发流数 = $total_fs"

            # 清理 client 容器日志
            kubectl exec "$client" -- bash -c \
                "mkdir -p logs/bw logs/lat || true; rm -rf logs/bw/* logs/lat/* /tmp/sockperf_*.csv /tmp/sockperf_*.log /tmp/sockperf_single.* /tmp/iperf_*.log || true"

            # -----------------------------
            # iperf 并发流测试 (容器内并发 + 不阻塞)
            # -----------------------------
            full_procs=$(( total_fs / MAX_IPERF_STREAMS ))
            remainder=$(( total_fs % MAX_IPERF_STREAMS ))

            iperf_cmds=""
            for i in $(seq 0 $((full_procs-1))); do
                port=$((IPERF_PORT+i))
                LOG_FILE="/tmp/iperf_${port}.log"
                iperf_cmds+="iperf -c ${SERVER_IP} -p $port -P $MAX_IPERF_STREAMS -t ${DURATION} -i ${DURATION} > $LOG_FILE 2>&1 & "
            done
            if [[ $remainder -gt 0 ]]; then
                port=$((IPERF_PORT+full_procs))
                LOG_FILE="/tmp/iperf_${port}.log"
                iperf_cmds+="iperf -c ${SERVER_IP} -p $port -P $remainder -t ${DURATION} -i ${DURATION} > $LOG_FILE 2>&1 & "
            fi
            # （注意：不在此处放 wait，交由后面的组合命令等待）

            echo "[INFO] 启动 iperf (并发流=${total_fs})"

            # -----------------------------
            # sockperf 单流延迟测试（与 iperf 并发运行）
            # -----------------------------
            # echo "[INFO] 启动单条 sockperf under-load 测试（和 iperf 同期）"
            # sockperf_cmd="sockperf under-load --tcp -i ${SERVER_IP} -p ${SOCKPERF_PORT} -t ${DURATION} -m 1472 --full-log /tmp/sockperf_single.csv > /tmp/sockperf_single.log 2>&1 & "

            # 组合命令：启动 iperf 进程 ，然后 wait 等待全部结束
            combined_cmd="${iperf_cmds} wait"

            # 在 client 容器内执行组合命令（所有进程并行运行）
            kubectl exec "$client" -- bash -lc "$combined_cmd"

            # -----------------------------
            # 拉回日志（一次性在容器打包流出，避免大量 kubectl cp 导致的性能问题/警告）
            # -----------------------------
            mkdir -p "${OUTDIR}/${cur}/${id}/${total_fs}"

            # 从容器 /tmp 打包 iperf_*.log 与 sockperf_single.* 并在本地解包
            kubectl exec "$client" -- bash -lc "\
                cd /tmp || exit 0; \
                shopt -s nullglob; \
                files=(iperf_*.log sockperf_single.* sockperf_*.csv sockperf_*.log); \
                if [ \${#files[@]} -gt 0 ]; then tar cf - \"\${files[@]}\"; fi" \
              | tar -C "${OUTDIR}/${cur}/${id}/${total_fs}" --no-same-owner -xvf - 2>/dev/null || true

        done

        # -----------------------------
        # 清理/恢复策略（仅在最后一次 run 时执行）
        # -----------------------------
        if [[ "$cur" == "beeqos" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            cd .. && bash remove_beeqos_after_calico.sh && cd -
            kubectl delete -f yamls/server.yaml --grace-period=0 --force
            kubectl delete -f yamls/client.yaml --grace-period=0 --force
        fi

        if [[ "$cur" == "htb" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            ssh root@10.102.0.235 'sudo bash -s' < ./unset_htb.sh
            kubectl delete -f yamls/server.yaml --grace-period=0 --force
            kubectl delete -f yamls/client.yaml --grace-period=0 --force
        fi

        if [[ "$cur" == "cilium" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            kubectl delete -f yamls/iperf-server-cilium.yaml --grace-period=0 --force
            kubectl delete -f yamls/iperf-client-cilium.yaml --grace-period=0 --force
        fi

        echo "[INFO] Logs moved to ${OUTDIR}/${cur}/${id} ✅"
    done
done
