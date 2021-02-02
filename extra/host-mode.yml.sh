#!/usr/bin/env bash

cat << EOF
version: '3.5'
services:
  ${GOJIRA_TARGET:-kong}:
    environment:
      KONG_PG_HOST: ${KONG_PG_HOST:-localhost}
      KONG_CASSANDRA_CONTACT_POINTS: ${KONG_CASSANDRA_CONTACT_POINTS:-localhost}
      KONG_REDIS_HOST: ${KONG_REDIS_HOST:-localhost}

      KONG_TEST_PG_HOST: ${KONG_PG_HOST:-localhost}
      KONG_TEST_CASSANDRA_CONTACT_POINTS: ${KONG_CASSANDRA_CONTACT_POINTS:-localhost}
      KONG_SPEC_REDIS_HOST: ${KONG_SPEC_REDIS_HOST:-localhost}
EOF
