
DEV=ens58f1

# 清理旧规则
tc qdisc del dev $DEV root 2>/dev/null

# 1. HTB 根队列
tc qdisc add dev $DEV root handle 1: htb default 20

# 2. 根 class，总带宽 1G
tc class add dev $DEV parent 1: classid 1:1 htb rate 1Gbit ceil 1Gbit

tc class add dev $DEV parent 1:1 classid 1:10 htb rate 600Mbit ceil 1Gbit prio 2

tc filter add dev $DEV protocol ip parent 1:0 prio 1 u32 \
  match ip src 10.255.24.1/32 \
  flowid 1:10

# 状态查看
# echo; echo "[qdisc]"
# tc -s qdisc show dev $DEV
# echo; echo "[classes]"
# tc -s class show dev $DEV
echo; echo "[filters]"
tc filter show dev $DEV