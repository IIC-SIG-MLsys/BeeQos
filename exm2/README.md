# 动态保障试验
在server端启动两个iperf server容器模拟业务端，对应高和其他两个优先级
在client端启动两个iperf client容器，每个内部运行下面的多线程脚本进行带宽和时延的测量

低优先级启动4条流作为背景任务，不指定带宽，表示它们有多少流量用多少
高优先级分时段启动不同数量的流以达到动态需求的模拟，指定带宽，流数少时表示需求小，流数增多表示需求增加。测试时会为高优任务设置保障带宽，测试要在保障带宽上下改变，以测试我们方案能不能在高优先级需要流量的时候给他保障。
oncn，tc-htb，cilium，不限速 四种情况的。

总的带宽利用率变化趋势 fig2-1：随着时间的进行，总利用率的变化情况，
高优先级流的带宽和变化趋势（红）fig2-2
低优先级流的带宽变化趋势 fig2-3

## 物理机测试脚本
```
# 生成配置脚本
bash iperf.sh genconf

# 启动低优先级服务
bash iperf.sh low-server -f results/exm2.conf -o results
# 启动高优先级服务
bash iperf.sh high-server -f results/exm2.conf -o results

# 启动低优先级客户端
bash iperf.sh low-client -h 192.168.100.2 -f results/exm2.conf -o results
# 启动高优先级客户端
bash iperf.sh high-client -h 192.168.100.2 -f results/exm2.conf -o results

# 提取结果
bash iperf.sh extract -f results/exm2.conf -o results
```

## k8s试验
```
bash run_iperf3.sh

ssh root@10.102.0.235 'sudo bash -s' < ./set_htb.sh
```