REMOTE_USER="liujinyao" # k8s user
REMOTE_IP="10.102.0.235"
REMOTE_DIR="/home/${REMOTE_USER}/k8s"
NAMESPACE="k8s.io"

cd bwm/install/kubernetes
kubectl apply -f oncn-bwm.yaml
cd -

sleep 1

# 增加bwm为calico插件
ssh root@${REMOTE_IP} 'jq '\''if any(.plugins[]; .name=="bwm-cni") 
  then . 
  else .plugins += [{
    "name": "bwm-cni",
    "log_level": "debug",
    "type": "bwm-cni",
    "cniVersion": "1.0.0"
  }] 
  end'\'' /etc/cni/net.d/10-calico.conflist | sudo tee /etc/cni/net.d/10-calico.conflist > /dev/null'