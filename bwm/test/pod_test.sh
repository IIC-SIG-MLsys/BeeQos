#!/bin/bash

# pod test
cd pod_test
cd egress
sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 10Mb
sleep 10
sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 10Mb 512 1
sleep 10
sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 10Mb 128KB 64
sleep 10
sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 10Mb 512 64
sleep 10

#kubectl delete -f 0-egress-iperf3-client.yaml
#kubectl delete -f 1-egress-iperf3-client.yaml
#kubectl delete -f 2-egress-iperf3-client.yaml
#kubectl delete -f egress-iperf3-server.yaml
#sleep 30

cd ../ingress
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 10Mb
sleep 10
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 10Mb 512 1
sleep 10
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 10Mb 128KB 64
sleep 10
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 10Mb 512 64
sleep 10

#kubectl delete -f 0-ingress-iperf3-server.yaml
#kubectl delete -f 1-ingress-iperf3-server.yaml
#kubectl delete -f 2-ingress-iperf3-server.yaml
#kubectl delete -f ingress-iperf3-client.yaml
#sleep 30

# pod mix test
cd ../mix_test
sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 10Mb &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 10Mb &
sleep 80

sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 10Mb 512 1 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 10Mb 512 1 &
sleep 80

sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 10Mb 128KB 4 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 10Mb 128KB 4 &
sleep 80

sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 10Mb 512 4 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 10Mb 512 4 &
sleep 80

sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 10Mb 128KB 64 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 10Mb 128KB 64 &
sleep 80

sh -x bwm-test-egress.sh  1000 1 500Mb 2 200Mb 1 10Mb 512 64 &
sh -x bwm-test-ingress.sh 1000 1 500Mb 2 200Mb 1 10Mb 512 64 &
sleep 80

