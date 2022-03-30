#!/usr/bin/env bash

cat << EOF
version: '3.5'
services:
  ${GOJIRA_TARGET:-kong}:
    # Purposeful empty image as default. If no KONG_IMAGE is set up at the
    # right context, we did something wrong. There are acceptable cases
    # where image is not needed (compose down, kill, etc)
    image: ${GOJIRA_IMAGE:-scratch}
    user: root
    command: "follow-kong-log"
    labels:
      com.konghq.gojira: True
    # Add net admin capabilities to containers to allow manipulating traffic
    # control settings (like adding network latency)
    cap_add:
      - NET_ADMIN
EOF

if [[ -n $GOJIRA_HOSTNAME ]]; then
  cat << EOF
    hostname: ${GOJIRA_HOSTNAME}
EOF
fi

if [ "$GOJIRA_NETWORK_MODE" != "host" ]; then
  cat << EOF
    ports:
      - 8000-8001
      - 8443-8444
EOF
  for port in $GOJIRA_PORTS; do
    cat << EOF
      - $port
EOF
  done
fi

cat << EOF
    volumes:
      - ${KONG_PREFIX:-/kong/servroot}
      - ${GOJIRA_HOME}/:/root/
      - ${DOCKER_CTX}/follow-log.sh:/bin/follow-kong-log
      - ${DOCKER_CTX}/gosh.sh:/bin/gosh:ro
      - ${DOCKER_CTX}/kong-att.sh:/bin/kong-att:ro
      # Inject env vars, since images might not have them
      - ${DOCKER_CTX}/42-kong-envs.sh:/etc/profile.d/42-kong-envs.sh
EOF

# Mount Kong path ONLY if it has been supplied
if [[ -n $GOJIRA_KONG_PATH ]]; then
cat << EOF
      - ${GOJIRA_KONG_PATH}:${KONG_PATH:-/kong}
EOF
fi

for volume in $GOJIRA_VOLUMES; do
cat << EOF
      - $volume
EOF
done



if [[ -n $GOJIRA_DATABASE ]] || [[ -n $GOJIRA_REDIS ]]; then
cat << EOF
    depends_on:
      $([[ -n $GOJIRA_DATABASE ]] && echo "- db")
      $([[ -n $GOJIRA_REDIS ]] && echo "- redis")
EOF
fi


if [[ -n $GOJIRA_KONG_PATH ]]; then
  cat << EOF
    working_dir: "${KONG_PATH:-/kong}"
EOF
fi


cat << EOF
    environment:
      KONG_ROLE: traditional
      KONG_PREFIX: ${KONG_PREFIX:-/kong/servroot}
      KONG_PLUGINS: bundled${KONG_PLUGINS:+,$KONG_PLUGINS}
      KONG_CUSTOM_PLUGINS: ${KONG_CUSTOM_PLUGINS}
      KONG_PATH: ${KONG_PATH:-/kong}
      KONG_PLUGIN_PATH: ${KONG_PLUGIN_PATH:-/kong-plugin}
      KONG_ADMIN_LISTEN: ${KONG_ADMIN_LISTEN:-0.0.0.0:8001}
      # need quotes for strategy off
      KONG_DATABASE: "${KONG_DATABASE:-postgres}"
      KONG_PG_DATABASE: ${KONG_PG_DATABASE:-kong}
      KONG_PG_HOST: ${KONG_PG_HOST:-db}
      KONG_PG_USER: ${KONG_PG_USER:-kong}
      KONG_ANONYMOUS_REPORTS: "${KONG_ANONYMOUS_REPORTS:-false}"
      KONG_CASSANDRA_CONTACT_POINTS: ${KONG_CASSANDRA_CONTACT_POINTS:-db}
      KONG_REDIS_HOST: ${KONG_REDIS_HOST:-redis}

      # need quotes for strategy off
      KONG_TEST_DATABASE: "${KONG_TEST_DATABASE:-${KONG_DATABASE:-postgres}}"
      KONG_TEST_PG_HOST: ${KONG_TEST_PG_HOST:-db}
      KONG_TEST_PG_DATABASE: ${KONG_TEST_PG_DATABASE:-kong_tests}
      KONG_TEST_CASSANDRA_CONTACT_POINTS: ${KONG_TEST_CASSANDRA_CONTACT_POINTS:-db}
      KONG_SPEC_REDIS_HOST: ${KONG_SPEC_REDIS_HOST:-redis}
      # DNS resolution on docker always has this ip. Since we have a qualified
      # name for the db server, we need to set up the DNS resolver, is set
      # to 8.8.8.8 on the spec conf
      KONG_TEST_DNS_RESOLVER: 127.0.0.11
EOF

# Some tests do not like KONG_TEST_PLUGINS being set
if [[ -n $KONG_PLUGINS ]]; then
  cat << EOF
      KONG_TEST_PLUGINS: bundled${KONG_PLUGINS:+,$KONG_PLUGINS}
EOF
fi

cat << EOF
      GOJIRA_PREFIX: ${GOJIRA_PREFIX}

    restart: on-failure

EOF

if [[ -z $GOJIRA_NETWORK_MODE ]]; then
  cat << EOF
    networks:
      gojira:
EOF

  if [[ -n $GOJIRA_HOSTNAME ]]; then
    cat << EOF
        aliases:
          - ${GOJIRA_HOSTNAME}
EOF
  fi

else
  cat << EOF
    network_mode: ${GOJIRA_NETWORK_MODE}
EOF
fi

if [[ "$GOJIRA_NETWORK_MODE" != "host" ]]; then
  cat << EOF
    # Enable IPv6 inside the container for executing tests
    sysctls:
      net.ipv6.conf.all.disable_ipv6: 0
EOF

fi
if [[ -n $GOJIRA_DATABASE ]]; then
cat << EOF
  db:
    labels:
      com.konghq.gojira: True
EOF

  if [[ $GOJIRA_DATABASE == "postgres" ]]; then
    cat << EOF
    image: postgres:${POSTGRES:-9.5}
EOF

    if [ "$GOJIRA_NETWORK_MODE" != "host" ]; then
      cat << EOF
    ports:
      - 5432
EOF
    fi

    cat << EOF
    volumes:
      - ${DOCKER_CTX}/pg-entrypoint:/docker-entrypoint-initdb.d
      - ${GOJIRA_HOME}/:/root/
    environment:
      POSTGRES_DBS: ${KONG_PG_DATABASE:-kong},${KONG_TEST_PG_DATABASE:-kong_tests}
      POSTGRES_USER: ${KONG_PG_USER:-kong}
      POSTGRES_HOST_AUTH_METHOD: trust
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "${KONG_PG_USER:-kong}"]
      interval: 5s
      timeout: 10s
      retries: 10
    restart: on-failure
    stdin_open: true
    tty: true
EOF

  elif [[ $GOJIRA_DATABASE == "cassandra" ]]; then
    cat << EOF
    image: cassandra:${CASSANDRA:-3.11}
EOF

    if [ "$GOJIRA_NETWORK_MODE" != "host" ]; then
      cat << EOF
    ports:
      - 7000-7001
      - 7199
      - 9042
      - 9160
EOF
    fi

    cat << EOF
    volumes:
      - ${GOJIRA_HOME}/:/root/
    environment:
      MAX_HEAP_SIZE: 256M
      HEAP_NEWSIZE: 128M
    healthcheck:
      test: ["CMD", "cqlsh", "-e", "describe keyspaces"]
      interval: 5s
      timeout: 10s
      retries: 10
    restart: on-failure
EOF
  fi

  if [[ -z $GOJIRA_NETWORK_MODE ]]; then
    cat << EOF
    networks:
      gojira:
EOF

  else
    cat << EOF
    network_mode: ${GOJIRA_NETWORK_MODE}
EOF
  fi
fi

if [[ -n $GOJIRA_REDIS ]]; then
  cat << EOF
  redis:
    image: redis:${REDIS_VERSION:-5.0.4-alpine}
EOF

  if [ "$GOJIRA_NETWORK_MODE" != "host" ]; then
    cat << EOF
    ports:
      - 6379
EOF
  fi

  cat << EOF
    restart: on-failure
    labels:
      com.konghq.gojira: True
EOF

  if [[ $GOJIRA_REDIS_MODE == "cluster" ]]; then
    cat << EOF
    environment:
      - IP
      - REDIS_CLUSTER_NODES=${REDIS_CLUSTER_NODES:-6}
EOF
    if [[ -n $REDIS_PASSWORD ]]; then
      cat << EOF
      - REDIS_PASSWORD
EOF
    fi
cat << EOF
    volumes:
      - ${DOCKER_CTX}/redis-cluster.sh:/usr/local/bin/redis-cluster.sh
    command: ["sh", "/usr/local/bin/redis-cluster.sh"]
    healthcheck:
      test: ["CMD", "redis-cli", "-p", "7005", "ping"]
      interval: 5s
      timeout: 10s
      retries: 5
EOF
  else
    cat << EOF
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 10s
      retries: 10
EOF

    if [[ -n $REDIS_PASSWORD ]]; then
      cat << EOF
    command: ["redis-server", "--appendonly", "yes", "--requirepass", "$REDIS_PASSWORD"]
EOF
    fi
  fi

  if [[ -z $GOJIRA_NETWORK_MODE ]]; then
    cat << EOF
    networks:
      gojira:
EOF
  else
    cat << EOF
    network_mode: ${GOJIRA_NETWORK_MODE}
EOF
  fi
fi

if [[ -z $GOJIRA_NETWORK_MODE ]]; then
  cat << EOF
networks:
  gojira:
EOF

  if [[ -n $GOJIRA_NETWORK ]]; then
    cat << EOF
    name: ${GOJIRA_NETWORK}
EOF
  fi
fi
