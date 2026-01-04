#!/bin/bash

# pod test
cd pod_test
cd egress
sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 0
sleep 10
sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 0 512 1
sleep 10
sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 0 128KB 64
sleep 10
sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 0 512 64
sleep 10

cd ../ingress
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 0
sleep 10
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 0 512 1
sleep 10
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 0 128KB 64
sleep 10
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 0 512 64
sleep 10

# pod mix test
cd ../mix_test
sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 0 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 0 &
sleep 80

sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 0 512 1 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 0 512 1 &
sleep 80

sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 0 128KB 4 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 0 128KB 4 &
sleep 80

sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 0 512 4 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 0 512 4 &
sleep 80

sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 0 128KB 64 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 0 128KB 64 &
sleep 80

sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 0 512 64 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 0 512 64 &
sleep 80

kubectl delete -f 0-egress-iperf3-client.yaml
kubectl delete -f 1-egress-iperf3-client.yaml
kubectl delete -f 2-egress-iperf3-client.yaml
kubectl delete -f egress-iperf3-server.yaml
kubectl delete -f 0-ingress-iperf3-server.yaml
kubectl delete -f 1-ingress-iperf3-server.yaml
kubectl delete -f 2-ingress-iperf3-server.yaml
kubectl delete -f ingress-iperf3-client.yaml
sleep 60

# process test
cd ../../process_test
cd process_test
cd egress
sh -x process-bwm-test-egress.sh  1000 1 500 2 200 1 10 9.82.232.142 9.82.213.93
sleep 10
sh -x process-bwm-test-egress.sh  1000 1 500 2 200 1 10 9.82.232.142 9.82.213.93 512 1
sleep 10
sh -x process-bwm-test-egress.sh  1000 1 500 2 200 1 10 9.82.232.142 9.82.213.93 128KB 64
sleep 10
sh -x process-bwm-test-egress.sh  1000 1 500 2 200 1 10 9.82.232.142 9.82.213.93 512 64
sleep 10

cd ../ingress
sh -x process-bwm-test-ingress.sh 1000 1 500 2 200 1 10 9.82.213.93 9.82.232.142
sleep 10
sh -x process-bwm-test-ingress.sh 1000 1 500 2 200 1 10 9.82.213.93 9.82.232.142 512 1
sleep 10
sh -x process-bwm-test-ingress.sh 1000 1 500 2 200 1 10 9.82.213.93 9.82.232.142 128KB 64
sleep 10
sh -x process-bwm-test-ingress.sh 1000 1 500 2 200 1 10 9.82.213.93 9.82.232.142 512 64
sleep 10

# process mix test
cd ../mix_test
sh -x process-bwm-test-egress.sh  1000 1 500 2 200 1 10 9.82.232.142 9.82.213.93 &
sh -x process-bwm-test-ingress.sh 1000 1 500 2 200 1 10 9.82.213.93 9.82.232.142 &
sleep 80

sh -x process-bwm-test-egress.sh  1000 1 500 2 200 1 10 9.82.232.142 9.82.213.93 512 1 &
sh -x process-bwm-test-ingress.sh 1000 1 500 2 200 1 10 9.82.213.93 9.82.232.142 512 1 &
sleep 80

sh -x process-bwm-test-egress.sh  1000 1 500 2 200 1 10 9.82.232.142 9.82.213.93 128KB 8 &
sh -x process-bwm-test-ingress.sh 1000 1 500 2 200 1 10 9.82.213.93 9.82.232.142 128KB 8 &
sleep 80

sh -x process-bwm-test-egress.sh  1000 1 500 2 200 1 10 9.82.232.142 9.82.213.93 512 8 &
sh -x process-bwm-test-ingress.sh 1000 1 500 2 200 1 10 9.82.213.93 9.82.232.142 512 8 &
sleep 80

sh -x process-bwm-test-egress.sh  1000 1 500 2 200 1 10 9.82.232.142 9.82.213.93 128KB 64 &
sh -x process-bwm-test-ingress.sh 1000 1 500 2 200 1 10 9.82.213.93 9.82.232.142 128KB 64 &
sleep 80

sh -x process-bwm-test-egress.sh  1000 1 500 2 200 1 10 9.82.232.142 9.82.213.93 512 64 &
sh -x process-bwm-test-ingress.sh 1000 1 500 2 200 1 10 9.82.213.93 9.82.232.142 512 64 &
sleep 80

