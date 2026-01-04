REMOTE_USER="liujinyao" # k8s user
REMOTE_IP="10.102.0.235"
REMOTE_DIR="/home/${REMOTE_USER}/k8s"
NAMESPACE="k8s.io"

cd calico/v327

kubectl apply -f calico.yaml

cd -