#!/bin/bash

/etc/init.d/postgresql stop

rm -rf "${PGDATA:?}/"*

cat > ~/.pgpass.conf <<EOF
*:5432:replication:${PG_REP_USER}:${PG_REP_PASSWORD}
EOF
chmod 0600 ~/.pgpass.conf

until PGPASSFILE=~/.pgpass.conf pg_basebackup -h db -U "$PG_REP_USER" -p 5432 -D "$PGDATA" -Fp -Xs -P -R
do
    # If docker is starting the containers simultaneously, the backup may encounter
    # the primary amidst a restart. Retry until we can make contact.
    sleep 1
    echo "Retrying backup . . ."
done
chown -R postgres:postgres "$PGDATA"

/etc/init.d/postgresql start