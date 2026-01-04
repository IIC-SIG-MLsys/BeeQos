#!/bin/bash

total_bandwidth=$1
priority2_client_num=$2
priority2_limitrate=$3
priority1_client_num=$4
priority1_limitrate=$5
priority0_client_num=$6
priority0_limitrate=$7

# iperf3 test options
package_len=${8:-128KB}
connect_num=${9:-1}

sh -x bwm-test-egress.sh  $1 $2 $3 $4 $5 $6 $7 $package_len $connect_num &
sh -x bwm-test-ingress.sh $1 $2 $3 $4 $5 $6 $7 $package_len $connect_num &
