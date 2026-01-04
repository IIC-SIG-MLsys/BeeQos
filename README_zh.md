# BeeQos

BeeQos 是一个面向 Kubernetes 集群的 **细粒度 QoS 与带宽管理原型系统**，基于 **eBPF + TC** 实现。

本仓库包含：

* BeeQos / BWM 的核心实现代码
* Kubernetes 插件与部署脚本
* 基于 Calico / Cilium 的对照实验配置
* 论文实验所用的完整实验脚本与数据处理代码

---

## 1. 实验环境与前提条件

### 1.1 硬件与系统要求

* **至少两台物理服务器或虚拟机**
* Linux 内核支持 eBPF（推荐 ≥ 5.10）
* 服务器之间具备二层或三层互通网络

### 1.2 软件依赖

* Kubernetes（使用 `kubeadm` 部署）
* 容器运行时：`containerd`
* Go ≥ 1.20（用于编译控制组件）
* libbpf ≥ 1.3（从源码安装）

> ⚠️ **重要说明**
> 本仓库中的若干脚本和配置文件 **显式依赖网卡名和节点 IP**。
> 在运行任何 `.sh` 脚本前，请根据你的实验环境 **修改对应 IP / 网卡名称**。

---

## 2. 使用 kubeadm 创建 Kubernetes 集群

在控制节点执行：

```bash
sudo kubeadm reset -f \
  --cri-socket unix:///var/run/containerd/containerd.sock

sudo kubeadm init \
  --control-plane-endpoint=<MASTER_IP> \
  --pod-network-cidr=10.244.0.0/12 \
  --image-repository registry.aliyuncs.com/google_containers \
  --cri-socket unix:///var/run/containerd/containerd.sock \
  -v=10
```

配置 `kubectl`：

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 常见问题

若遇到 kubeconfig verification error，可执行：

```bash
sudo kubeadm init phase kubeconfig admin
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## 3. BeeQos / BWM 编译与镜像分发

### 3.1 获取源码并切换分支

```bash
git clone https://github.com/derekwin/demo-cli.git bwm
cd bwm
git checkout -b bwm origin/dhc-elf
cd ..
```

### 3.2 指定实验使用的物理网卡

编辑以下文件（示例中使用 `eno2`）：

```bash
bwm/cmd/alg-daemon/main.go
```

将自动探测改为固定网卡名：

```go
HostNICName, err := "eno2", nil
```

> 可恢复为自动探测（非实验环境）：

```go
HostNICName, err := common.GetMasterIntf()
```

### 3.3 编译与镜像分发

```bash
cd bwm
make all
cd ..
```

修改 `distribute_bwm.sh`：

* 镜像 tag
* 节点 IP
* 远程路径

然后执行：

```bash
bash distribute_bwm.sh
```

---

## 4. 安装 Calico + BeeQos（主实验路径）

### 4.1 安装 Calico（v3.27）

```bash
cd calico/v327
```

**中国大陆用户**：

* 请提前手动拉取 Calico 相关镜像

修改 `calico.yaml`：

* 指定物理网卡
* 关闭 `CALICO_IPV4POOL_IPIP`

执行：

```bash
bash setup_calico.sh
```

### 4.2 安装 BeeQos

```bash
cd bwm/install/kubernetes
kubectl apply -f oncn-bwm.yaml
cd -
```

配置 BeeQos 为 Calico 的带宽管理插件：

```bash
bash setup_beeqos_after_calico.sh
```

---

## 5. 安装 Cilium（对照实验）

> ⚠️ **注意**
> Cilium 与 BeeQos / Calico 冲突。
> 为保证实验一致性，**建议直接重建集群**。

### 5.1 卸载 BeeQos 与 Calico

```bash
kubectl delete -f bwm/install/kubernetes/oncn-bwm.yaml
kubectl delete -f calico/v327/calico.yaml
```

### 5.2 安装 Cilium（v1.18.1）

参考官方文档（Bandwidth Manager）：

> [https://docs.cilium.io/en/latest/network/kubernetes/bandwidth-manager/](https://docs.cilium.io/en/latest/network/kubernetes/bandwidth-manager/)

```bash
cilium install --version 1.18.1
```

启用带宽管理：

```bash
helm upgrade cilium ./cilium \
  --version 1.18.1 \
  --namespace kube-system \
  --reuse-values \
  --set bandwidthManager.enabled=true
```

重启：

```bash
kubectl -n kube-system rollout restart ds/cilium
```

---

## 6. 实验与结果复现

* `exm1` – `exm4`：论文中使用的实验
* 每个目录包含：

  * Kubernetes YAML
  * 运行脚本
  * 原始结果与处理脚本

---

## 7. 常用调试命令

```bash
kubectl -n kube-system get pods
kubectl -n kube-system exec -it <cilium-pod> -- cilium-dbg status | grep BandwidthManager
```

### 禁用无关网卡（减少实验干扰）

```bash
sudo ip link set ens61f0np0 down
sudo ip link set ens61f1np1 down
sudo ip link set enp129s0np0 down
```

### DNS 异常处理

```bash
kubectl delete pod -n kube-system -l k8s-app=kube-dns
```

---

## 8. 仓库结构概览

* `bwm/`：BeeQos 核心实现（eBPF / TC / Daemon）
* `calico/`：Calico 配置
* `exm*/`：论文实验
* `setup_*.sh`：环境配置脚本

