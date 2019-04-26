#!/usr/bin/env bash

cat << EOF
version: '3.5'
services:
  kong:
    # Purposeful empty image as default. If no KONG_IMAGE is set up at the
    # right context, we did something wrong. There are acceptable cases
    # where image is not needed (compose down, kill, etc)
    image: ${KONG_IMAGE:-scratch}
    user: root
    command: "tail -f /dev/null"
    volumes:
      - ${KONG_PATH:-./kong}:/kong
EOF

for volume in $(echo $GOJIRA_VOLUMES | tr "," " "); do
cat << EOF
      - $volume
EOF
done

cat << EOF
    depends_on:
      - db
    environment:
      KONG_PREFIX: /kong/servroot
      KONG_PLUGINS: ${KONG_PLUGINS:-bundled}
      KONG_PATH: /kong
      KONG_PLUGIN_PATH: /kong-plugin
      KONG_ADMIN_LISTEN: '0.0.0.0:8001'
      KONG_TEST_DATABASE: postgres
      KONG_DATABASE: postgres
      KONG_PG_DATABASE: ${KONG_PG_DATABASE:-kong_tests}
      KONG_PG_HOST: db
      KONG_TEST_PG_HOST: db
      KONG_PG_USER: ${KONG_PG_USER:-kong}
      KONG_ANONYMOUS_REPORTS: "false"
    restart: on-failure
    networks:
      - gojira
  db:
    image: postgres:9.5
    environment:
      POSTGRES_DB: ${KONG_PG_DATABASE:-kong_tests}
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
