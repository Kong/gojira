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
    ports:
      - 8001:8001

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
    ports:
      - 8000:8000

EOF
