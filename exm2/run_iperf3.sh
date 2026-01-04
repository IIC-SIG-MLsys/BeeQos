#!/bin/bash
set -euo pipefail

server_ip_low=$(kubectl get pod exm2-server-low -o jsonpath='{.status.podIP}')
server_ip_high_1=$(kubectl get pod exm2-server-high-1 -o jsonpath='{.status.podIP}')
server_ip_high_2=$(kubectl get pod exm2-server-high-2 -o jsonpath='{.status.podIP}')
client_pod=exm2-client

exm="
# priority,start_time,duration,port,bandwidth,parallel
low,0,50,5201,0,1
high1,10,10,5201,400M,1
high2,20,10,5201,800M,1
high1,30,10,5201,400M,1
"

max_end=0
while IFS=, read -r priority start_time duration port bandwidth parallel; do
  [[ -z "$priority" || "$priority" == \#* ]] && continue
  end_time=$((start_time + duration + 10))
  if (( end_time > max_end )); then
    max_end=$end_time
  fi
done <<< "$exm"

echo "$exm" | while IFS=, read -r priority start_time duration port bandwidth parallel; do
  [[ -z "$priority" || "$priority" == \#* ]] && continue

  if [[ "$priority" == "low" ]]; then
    server_ip=$server_ip_low
  else
    if [[ "$priority" == "high1" ]]; then
      server_ip=$server_ip_high_1
    else
      server_ip=$server_ip_high_2
    fi
  fi

  cmd="sleep $start_time && iperf3 -c $server_ip -p $port -P $parallel -t $duration -R"
  if [[ "$bandwidth" != "0" ]]; then
    cmd+=" -b $bandwidth"
  fi

  log_file="/logs/${priority}_${start_time}_${duration}.log"

  echo "[INFO] 启动: $cmd -> $log_file"

  kubectl exec "$client_pod" -- bash -c "$cmd > $log_file 2>&1" &
done

sleep "$max_end"

echo "[INFO] 所有 iperf 测试完成，日志在 /logs 下。"
