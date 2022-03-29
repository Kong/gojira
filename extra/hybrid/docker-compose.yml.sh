#!/usr/bin/env bash

cat << EOF
version: '3.5'
services:
  kong-cp:
    environment:
      KONG_ROLE: control_plane
      KONG_CLUSTER_CERT: /cluster/cluster.crt
      KONG_CLUSTER_CERT_KEY: /cluster/cluster.key
    volumes:
      - ${CLUSTER_KEY_PATH}:/cluster
EOF

for volume in $GOJIRA_VOLUMES; do
cat << EOF
      - $volume
EOF
done

if [ "$GOJIRA_NETWORK_MODE" != "host" ]; then
  if [[ -n $GOJIRA_PORTS ]]; then
    cat << EOF
      ports:
EOF
    for port in $GOJIRA_PORTS; do
      cat << EOF
          - $port
EOF
    done
  fi
fi

cat << EOF
  kong-dp:
    environment:
      KONG_ROLE: data_plane
      KONG_CLUSTER_CONTROL_PLANE: kong-cp:8005
      KONG_CLUSTER_CERT: /cluster/cluster.crt
      KONG_CLUSTER_CERT_KEY: /cluster/cluster.key
      KONG_LUA_SSL_TRUSTED_CERTIFICATE: /cluster/cluster.crt
      KONG_DATABASE: "off"
    volumes:
      - ${CLUSTER_KEY_PATH}:/cluster
EOF

for volume in $GOJIRA_VOLUMES; do
cat << EOF
      - $volume
EOF
done
