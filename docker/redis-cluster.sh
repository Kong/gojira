#!/usr/bin/env bash
for port in 7000 7001 7002 7003 7004 7005; 
do 
  sh -c "nohup redis-server --port $port --cluster-enabled yes --cluster-config-file redis-slave-$port-nodes.conf --cluster-node-timeout 5000 > nohup-$port.txt &"
done

sleep 5

if [ -z "$IP" ]; 
then 
  IP=$(hostname -i | awk '{print $1}'); 
fi

yes yes | redis-cli --cluster create ${IP}:7000 ${IP}:7001 ${IP}:7002 ${IP}:7003 ${IP}:7004 ${IP}:7005 --cluster-replicas 1

tail -f /dev/null

