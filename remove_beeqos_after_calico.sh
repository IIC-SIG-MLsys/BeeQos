REMOTE_USER="liujinyao" # k8s user
REMOTE_IP="10.102.0.235"
REMOTE_DIR="/home/${REMOTE_USER}/k8s"
NAMESPACE="k8s.io"

cd bwm/install/kubernetes
kubectl delete -f oncn-bwm.yaml
cd -

sleep 1

# 移除bwm为calico插件
ssh root@${REMOTE_IP} "jq 'if any(.plugins[]; .name==\"bwm-cni\") 
  then .plugins |= map(select(.name != \"bwm-cni\")) 
  else . end' /etc/cni/net.d/10-calico.conflist | sudo tee /etc/cni/net.d/10-calico.conflist > /dev/null"
