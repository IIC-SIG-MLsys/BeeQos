REMOTE_USER="liujinyao" # k8s user
REMOTE_IP="10.102.0.235"
REMOTE_DIR="/home/${REMOTE_USER}/k8s"
NAMESPACE="k8s.io"

cd calico/v327
# 下载好calico所需镜像
# 修改calico.yaml，指定网卡，关闭CALICO_IPV4POOL_IPIP

scp -r calico* ${REMOTE_USER}@${REMOTE_IP}:${REMOTE_DIR}
ssh root@${REMOTE_IP} "cd ${REMOTE_DIR} && ctr -n ${NAMESPACE} i import calico-cni.tar"
ssh root@${REMOTE_IP} "cd ${REMOTE_DIR} && ctr -n ${NAMESPACE} i import calico-con.tar"
ssh root@${REMOTE_IP} "cd ${REMOTE_DIR} && ctr -n ${NAMESPACE} i import calico-node.tar"

sudo ctr -n ${NAMESPACE} i import calico-cni.tar
sudo ctr -n ${NAMESPACE} i import calico-con.tar
sudo ctr -n ${NAMESPACE} i import calico-node.tar

cd -