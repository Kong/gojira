#!/usr/bin/env bash
for i in $(seq 1 ${REDIS_CLUSTER_NODES});
do
  i=$((i - 1))
  sh -c "nohup redis-server --port 700$i --cluster-enabled yes --cluster-config-file redis-slave-700$i-nodes.conf --cluster-node-timeout 5000 > nohup-700$i.txt &"
done

sleep 5

if [ -z "$IP" ]; 
then 
  IP=$(hostname -i | awk '{print $1}'); 
fi

yes yes | redis-cli --cluster create $(for i in $(seq 1 ${REDIS_CLUSTER_NODES}); do i=$((i - 1)); printf "${IP}:700$i "; done) --cluster-replicas 1

tail -f /dev/null

