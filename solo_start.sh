#!/bin/bash
set -o pipefail

ACCOUNT_NAME=sipalingtestnet
POOL="aleo-seoul.ace1pool.com:8000"

WORKSPACE=$PWD
LOG_PATH="$WORKSPACE/prover.log"
APP_PATH="$WORKSPACE/aleo-prover-cuda"


cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
cpu_affinity=($(nvidia-smi topo -m 2>/dev/null | awk -F'\t+| {2,}' '{for (i=1;i<=NF;i++) if($i ~ /CPU Affinity/) col=i; if (NR != 1 && $0 ~ /^GPU/) print $col}'))
gpu_num=${#cpu_affinity[*]}

cat <<EOF
======================================

Account name: $ACCOUNT_NAME
Pool: $POOL

Number of gpus: $gpu_num
Number of cores: $cpu_cores

======================================

EOF

if [ $gpu_num -eq 0 ]; then
    nohup $APP_PATH -t 7 -j $(( $cpu_cores / 7 )) -a $ACCOUNT_NAME -p "$POOL" >> $LOG_PATH 2>&1 &

    echo "nohup $APP_PATH -t 7 -j $(( $cpu_cores / 7 )) -a $ACCOUNT_NAME -p \"$POOL\" >> $LOG_PATH 2>&1 &"
elif [ $gpu_num -eq 1 ]; then
    nohup $APP_PATH -g 0 -a $ACCOUNT_NAME -p "$POOL" >> $LOG_PATH 2>&1 &

    echo "nohup $APP_PATH -g 0 -a $ACCOUNT_NAME -p \"$POOL\" >> $LOG_PATH 2>&1 &"
else
    physical_cores=$(( cpu_cores / 2 ))
    append=$(( physical_cores % gpu_num ))
    span=$(( physical_cores / gpu_num ))

    for gpu_seq in $(seq 0 $((gpu_num-1))); do
        cpu_list="$((gpu_seq * span))-$(((gpu_seq+1) * span - 1)),$((gpu_seq * span + physical_cores))-$(((gpu_seq+1) * span + physical_cores - 1))"
        if [[ $append -gt 0 ]]; then
            cpu_list+=",$(( physical_cores - append )),$(( cpu_cores - append ))"
            append=$(( append - 1 ))
        fi
        nohup taskset -c $cpu_list $APP_PATH -g $gpu_seq -a $ACCOUNT_NAME -p "$POOL" >> $LOG_PATH 2>&1 &
        echo "nohup taskset -c $cpu_list $APP_PATH -g $gpu_seq -a $ACCOUNT_NAME -p \"$POOL\" >> $LOG_PATH 2>&1 &"
    done
fi
