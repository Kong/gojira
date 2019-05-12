#!/usr/bin/env bash

cat << EOF
version: '3.5'
services:
  kong:
    # Purposeful empty image as default. If no KONG_IMAGE is set up at the
    # right context, we did something wrong. There are acceptable cases
    # where image is not needed (compose down, kill, etc)
    image: ${GOJIRA_IMAGE:-scratch}
    user: root
    command: "follow-kong-log"
EOF

if [[ ! -z $GOJIRA_HOSTNAME ]]; then
cat << EOF
    hostname: ${GOJIRA_HOSTNAME}
EOF
fi

if [[ ! -z $GOJIRA_PORTS ]]; then
cat << EOF
    ports:
EOF
  for port in $(echo $GOJIRA_PORTS | tr "," " "); do
cat << EOF
      - $port
EOF
  done
fi

cat << EOF
    volumes:
      - ${GOJIRA_KONG_PATH}:${KONG_PATH:-/kong}
EOF

for volume in $(echo $GOJIRA_VOLUMES | tr "," " "); do
cat << EOF
      - $volume
EOF
done

if [[ ! -z $GOJIRA_DATABASE ]]; then
cat << EOF
    depends_on:
      - db
EOF
fi
cat << EOF
    environment:
      KONG_PREFIX: ${KONG_PREFIX:-/kong/servroot}
      KONG_PLUGINS: ${KONG_PLUGINS:-bundled}
      KONG_CUSTOM_PLUGINS: ${KONG_CUSTOM_PLUGINS}
      KONG_PATH: ${KONG_PATH:-/kong}
      KONG_PLUGIN_PATH: ${KONG_PLUGIN_PATH:-/kong-plugin}
      KONG_ADMIN_LISTEN: ${KONG_ADMIN_LISTEN:-0.0.0.0:8001}
      KONG_DATABASE: ${GOJIRA_DATABASE:-$KONG_DATABASE}
      KONG_PG_DATABASE: ${KONG_PG_DATABASE:-kong}
      KONG_PG_HOST: ${KONG_PG_HOST:-db}
      KONG_PG_USER: ${KONG_PG_USER:-kong}
      KONG_ANONYMOUS_REPORTS: "${KONG_ANONYMOUS_REPORTS:-false}"
      KONG_CASSANDRA_CONTACT_POINTS: ${KONG_CASSANDRA_CONTACT_POINTS:-db}
      KONG_TEST_DATABASE: ${GOJIRA_DATABASE:-$KONG_DATABASE}
      KONG_TEST_PG_HOST: ${KONG_TEST_PG_HOST:-db}
      KONG_TEST_PG_DATABASE: ${KONG_TEST_PG_DATABASE:-kong_tests}
      KONG_TEST_CASSANDRA_CONTACT_POINTS: ${KONG_TEST_CASSANDRA_CONTACT_POINTS:-db}

    restart: on-failure
    networks:
      gojira:
EOF

if [[ ! -z $GOJIRA_HOSTNAME ]]; then
cat << EOF
        aliases:
          - ${GOJIRA_HOSTNAME}
EOF
fi

if [[ $GOJIRA_DATABASE == "postgres" ]]; then
cat << EOF
  db:
    image: postgres:${POSTGRES:-9.5}
    volumes:
      - ${DOCKER_CTX}/pg-entrypoint:/docker-entrypoint-initdb.d
    environment:
      POSTGRES_DBS: ${KONG_PG_DATABASE:-kong},${KONG_TEST_PG_DATABASE:-kong_tests}
      POSTGRES_USER: ${KONG_PG_USER:-kong}
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "${KONG_PG_USER:-kong}"]
      interval: 5s
      timeout: 10s
      retries: 10
    restart: on-failure
    stdin_open: true
    tty: true
    networks:
      - gojira
EOF
elif [[ $GOJIRA_DATABASE == "cassandra" ]]; then
cat << EOF
  db:
    image: cassandra:${CASSANDRA:-3.9}
    environment:
      MAX_HEAP_SIZE: 256M
      HEAP_NEWSIZE: 128M
    healthcheck:
      test: ["CMD", "cqlsh", "-e", "describe keyspaces"]
      interval: 5s
      timeout: 10s
      retries: 10
    restart: on-failure
    networks:
      - gojira
EOF
fi

cat << EOF

networks:
  gojira:
EOF

if [[ ! -z $GOJIRA_NETWORK ]]; then
cat << EOF
    name: ${GOJIRA_NETWORK}
EOF
fi

cat << EOF

EOF
