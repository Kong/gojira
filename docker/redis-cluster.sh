#!/usr/bin/env bash
for i in $(seq 0 $((REDIS_CLUSTER_NODES - 1)));
do
  port=$((7000+$i))
  sh -c "nohup redis-server --port $port --cluster-enabled yes --cluster-config-file redis-slave-$port-nodes.conf --cluster-node-timeout 5000 > nohup-$port.txt &"
done

sleep 5

if [ -z "$IP" ]; 
then 
  IP=$(hostname -i | awk '{print $1}'); 
fi

yes yes | redis-cli --cluster create $(for i in $(seq 0 $((REDIS_CLUSTER_NODES - 1))); do port=$((7000+$i)); printf "${IP}:$port "; done) --cluster-replicas 1

tail -f /dev/null

