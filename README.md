# BeeQos

BeeQos is a **research prototype** for fine-grained QoS and bandwidth management in Kubernetes clusters.
It is implemented based on **eBPF and Linux Traffic Control (TC)**.

This repository includes:

* The core implementation of BeeQos / BWM
* Kubernetes plugins and deployment scripts
* Experimental configurations based on **Calico** and **Cilium** (for comparison)
* Complete experiment scripts and result processing code used in the paper

---

## 1. Experimental Environment and Prerequisites

### 1.1 Hardware and System Requirements

* **At least two physical machines or virtual machines**
* Linux kernel with eBPF support (recommended ≥ 5.10)
* L2 or L3 network connectivity between nodes

### 1.2 Software Dependencies

* Kubernetes (deployed via `kubeadm`)
* Container runtime: `containerd`
* Go ≥ 1.20 (for building control components)
* libbpf ≥ 1.3 (installed from source)

> ⚠️ **Important Notice**
> Several scripts and configuration files in this repository **explicitly depend on physical NIC names and node IP addresses**.
> Before executing any `.sh` script, please **modify IP addresses and NIC names according to your own environment**.

---

## 2. Kubernetes Cluster Setup with kubeadm

On the control-plane node:

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

Configure `kubectl`:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Known Issue

If a kubeconfig verification error occurs, execute:

```bash
sudo kubeadm init phase kubeconfig admin
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## 3. BeeQos / BWM Build and Image Distribution

### 3.1 Clone Source Code and Switch Branch

```bash
git clone https://github.com/derekwin/demo-cli.git bwm
cd bwm
git checkout -b bwm origin/dhc-elf
cd ..
```

### 3.2 Specify the Physical Network Interface

Edit the following file (example uses `eno2`):

```bash
bwm/cmd/alg-daemon/main.go
```

Replace automatic detection with a fixed NIC name:

```go
HostNICName, err := "eno2", nil
```

> To restore automatic detection (non-experimental use):

```go
HostNICName, err := common.GetMasterIntf()
```

### 3.3 Build and Distribute Images

```bash
cd bwm
make all
cd ..
```

Edit `distribute_bwm.sh`:

* Image tag
* Node IP addresses
* Remote deployment path

Then execute:

```bash
bash distribute_bwm.sh
```

---

## 4. Calico + BeeQos Installation (Main Experimental Setup)

### 4.1 Install Calico (v3.27)

```bash
cd calico/v327
```

**For users in mainland China**:

* Please pull required Calico images manually in advance.

Edit `calico.yaml`:

* Specify the physical NIC
* Disable `CALICO_IPV4POOL_IPIP`

Install Calico:

```bash
bash setup_calico.sh
```

### 4.2 Install BeeQos

```bash
cd bwm/install/kubernetes
kubectl apply -f oncn-bwm.yaml
cd -
```

Configure BeeQos as Calico’s bandwidth management plugin:

```bash
bash setup_beeqos_after_calico.sh
```

---

## 5. Cilium Installation (Baseline / Comparison)

> ⚠️ **Warning**
> Cilium conflicts with BeeQos and Calico.
> For experimental consistency, **rebuilding the Kubernetes cluster is strongly recommended**.

### 5.1 Remove BeeQos and Calico

```bash
kubectl delete -f bwm/install/kubernetes/oncn-bwm.yaml
kubectl delete -f calico/v327/calico.yaml
```

### 5.2 Install Cilium (v1.18.1)

Please refer to the official documentation (Bandwidth Manager):

[https://docs.cilium.io/en/latest/network/kubernetes/bandwidth-manager/](https://docs.cilium.io/en/latest/network/kubernetes/bandwidth-manager/)

```bash
cilium install --version 1.18.1
```

Enable bandwidth management:

```bash
helm upgrade cilium ./cilium \
  --version 1.18.1 \
  --namespace kube-system \
  --reuse-values \
  --set bandwidthManager.enabled=true
```

Restart Cilium:

```bash
kubectl -n kube-system rollout restart ds/cilium
```

---

## 6. Experiments and Result Reproduction

* `exm1` – `exm4`: experiments used in the paper
* Each directory contains:

  * Kubernetes YAML files
  * Execution scripts
  * Raw results and result processing scripts

---

## 7. Common Debugging Commands

```bash
kubectl -n kube-system get pods
kubectl -n kube-system exec -it <cilium-pod> -- cilium-dbg status | grep BandwidthManager
```

### Disable Unused NICs (to Reduce Experimental Interference)

```bash
sudo ip link set ens61f0np0 down
sudo ip link set ens61f1np1 down
sudo ip link set enp129s0np0 down
```

### DNS Issue Mitigation

```bash
kubectl delete pod -n kube-system -l k8s-app=kube-dns
```

---

## 8. Repository Structure Overview

* `bwm/` – Core BeeQos implementation (eBPF / TC / Daemons)
* `calico/` – Calico configuration
* `exm*/` – Experimental workloads and scripts
* `setup_*.sh` – Environment setup scripts
