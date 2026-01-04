# BeeQos

## 准备
- 最少两台服务器
- 安装k8s环境，安装kubeadm，本项目以containerd为容器后端

注意：下面任意一步的sh脚本，如果有涉及到ip，都需要改为你所在环境的对应服务器的ip。

## 使用kubadm创建k8s集群
```
sudo kubeadm reset -f  --cri-socket unix:///var/run/containerd/containerd.sock

sudo kubeadm init --control-plane-endpoint=10.102.0.242 --pod-network-cidr=10.244.0.0/12 --image-repository registry.aliyuncs.com/google_containers --cri-socket unix:///var/run/containerd/containerd.sock -v=10

mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
ps. verification error bug: `sudo kubeadm init phase kubeconfig admin && sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config`

## 开发环境配置
1. 从源代码安装libbpf1.3
2. 配置golang环境

## bwm代码编译
```
git clone https://github.com/derekwin/demo-cli.git bwm && cd bwm && git checkout -b bwm origin/dhc-elf && cd ..

# 指定实验使用的网卡，这里是eno2
sed -i 's/^\(\s*\)HostNICName, err := common.GetMasterIntf().*/\1HostNICName, err := "eno2", nil/' bwm/cmd/alg-daemon/main.go
# sed -i 's/^\(\s*\)HostNICName, err := "eno2", nil/\1HostNICName, err := common.GetMasterIntf()/' bwm/cmd/alg-daemon/main.go

cd bwm && make all && cd ..

# 修改distribute_bwm.sh中镜像的tag为刚刚生成的tag
# 修改试验服务器的ip等配置，运行下面脚本把镜像分发到各个节点
bash distribute_bwm.sh
```

## 为集群安装calico和bwm插件
以calico3.27版本

cd calico/v327
1. 如果你在中国大陆，需要提前下载好calico所需镜像
2. 修改calico.yaml，指定网卡，关闭CALICO_IPV4POOL_IPIP
```
bash setup_calico.sh
```

## 安装BeeQos
```
cd ./bwm/install/kubernetes && kubectl apply -f oncn-bwm.yaml && cd -
```
```
# 该脚本会自动将beeqos配置为calico的带宽管理插件
bash setup_beeqos_after_calico.sh
```

# 安装cilium（对照实验才需要）
注意安装cilium，要卸载掉bwm和calico，更保险的方式是，最好重建集群
```
cd ./bwm/install/kubernetes && kubectl delete -f oncn-bwm.yaml
cd -
cd ./calico/v327 && kubectl delete -f calico.yaml
cd -
```

参考：
https://docs.cilium.io/en/latest/network/kubernetes/bandwidth-manager/
```
# 安装cilium cli
wget https://github.com/cilium/cilium/archive/refs/tags/v1.18.1.tar.gz
tar xzf v1.18.1.tar.gz
cd cilium-1.18.1/install/kubernetes

bash distribute_cilium.sh root 10.102.0.235 /liujinyao/k8s

# 如果直接用helm安装不成功，先用cilium安装
cilium install --version 1.18.1

# 用helm更新带宽管理
helm upgrade cilium ./cilium --version 1.18.1 \
  --namespace kube-system \
  --reuse-values \
  --set bandwidthManager.enabled=true
kubectl -n kube-system rollout restart ds/cilium

# cilium uninstall
bash clean_cilium.sh
然后重新配置集群
```
> 修改http proxy后记得清理，否则会影响安装


### 常用命令
```
查看状态
kubectl -n kube-system get pods -l k8s-app=cilium

kubectl -n kube-system exec -it cilium-4s2qk -- cilium-dbg status | grep BandwidthManager
kubectl -n kube-system exec -it cilium-g9jr5 -- cilium-dbg status | grep BandwidthManager
BandwidthManager:        EDT with BPF [CUBIC] [ens58f1, ens61f0np0, ens61f1np1]
BandwidthManager:        EDT with BPF [CUBIC] [eno1, enp129s0np0]
```

##### 其他，为了防止其他网卡干扰实验，可以先禁用无关网卡
sudo ip link set ens61f0np0 down
sudo ip link set ens61f1np1 down
sudo ip link set enp129s0np0 down

##### 如果碰到dns问题
kubectl delete pod -n kube-system -l k8s-app=kube-dns