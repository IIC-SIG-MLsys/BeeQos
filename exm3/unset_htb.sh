#!/bin/bash
DEV=ens58f1

echo "[INFO] 清理 $DEV 上的 HTB 队列..."
tc qdisc del dev $DEV root 2>/dev/null

echo "[INFO] 已清理完成"
tc qdisc show dev $DEV

# 状态查看
# echo; echo "[qdisc]"
# tc -s qdisc show dev $DEV
# echo; echo "[classes]"
# tc -s class show dev $DEV
echo; echo "[filters]"
tc filter show dev $DEV