#!/bin/bash

# 实验名列表
# EXPERIMENTS=("beeqos" "htb" "no-shaper")
# EXPERIMENTS=("no-shaper")
# EXPERIMENTS=("beeqos" "htb")
EXPERIMENTS=("cilium")

# 循环次数
NUM_RUNS=1

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
            kubectl apply -f yamls/godash_test_cilium.yaml
            kubectl apply -f yamls/dash_server_nginx_cilium.yaml
            kubectl apply -f yamls/file_server_cilium.yaml
            kubectl apply -f yamls/file_download_cilium.yaml
            # 先运行一次，启动了容器，再跑试验
            # 启动之后查一下dash server 的 ip，然后改到 logs/configure_beeqos.conf
        else 
            kubectl apply -f yamls/godash_test.yaml
            kubectl apply -f yamls/dash_server_nginx.yaml
            kubectl apply -f yamls/file_server.yaml
            kubectl apply -f yamls/file_download.yaml
        fi

        echo "[INFO] 等待 Pod 启动并就绪..."
        pods=("dash-server" "godash-test" "exm6-file-client" "exm6-file-server")
        for pod in "${pods[@]}"; do
        echo "  -> 等待 $pod Ready..."
        kubectl wait --for=condition=ready pod/"$pod" --timeout=60s
        done
        echo "[INFO] 所有 Pod 已经就绪 ✅"

        fileServerIp=$(kubectl get pod exm6-file-server -o jsonpath='{.status.podIP}')
        echo "file server ip ${fileServerIp}"
        kubectl exec exm6-file-client -- iperf3 -c $fileServerIp -p 5201 -P 100 -t 300 -R > /tmp/log.log 2>&1 &
        kubectl exec -it godash-test -- bash -c "cd /logs && bash multi_client.sh"
        kubectl exec exm6-file-client -- pkill iperf3

        kubectl exec -it godash-test -- pkill godash
    
        # sudo rm -rf logs/godash_parallel/*
        # sudo rm -rf logs/excel/
        # sudo rm -rf logs/dash_exm/

        mkdir -p logs/dash_exm/$cur/$id
        sudo chown -R $USER:$USER logs/godash_parallel
        mv logs/godash_parallel/* logs/dash_exm/$cur/$id/

        # kubectl delete -f yamls/godash_test.yaml --grace-period=0 --force
        # kubectl delete -f yamls/dash_server_nginx.yaml --grace-period=0 --force
        # kubectl delete -f yamls/file_server.yaml --grace-period=0 --force
        # kubectl delete -f yamls/file_download.yaml --grace-period=0 --force

        # kubectl delete -f yamls/godash_test_cilium.yaml --grace-period=0 --force
        # kubectl delete -f yamls/dash_server_nginx_cilium.yaml --grace-period=0 --force
        # kubectl delete -f yamls/file_server_cilium.yaml --grace-period=0 --force
        # kubectl delete -f yamls/file_download_cilium.yaml --grace-period=0 --force

        if [[ "$cur" == "beeqos" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            cd .. && bash remove_beeqos_after_calico.sh && cd -
        fi

        if [[ "$cur" == "htb" && "$id" -eq $((NUM_RUNS-1)) ]]; then
            ssh root@10.102.0.235 'sudo bash -s' < ./unset_htb.sh
        fi

        echo "[INFO] Logs moved to logs/dash_exm/$cur/$id"
    done
done


