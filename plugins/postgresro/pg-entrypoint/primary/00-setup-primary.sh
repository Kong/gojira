#!/bin/bash

pg_conf_file=$PGDATA/postgresql.conf

echo "\
log_statement = 'all'
log_disconnections = off
log_duration = on
log_min_duration_statement = -1
shared_preload_libraries = 'pg_stat_statements'
track_activity_query_size = 2048
pg_stat_statements.track = all
pg_stat_statements.max = 10000
wal_level = hot_standby
archive_mode = on
archive_command = 'cd .'
max_wal_senders = 8
hot_standby = on
" >>$pg_conf_file

for database in $(echo $POSTGRES_DBS | tr ',' ' '); do
  echo "Creating database $database"
  psql -U $POSTGRES_USER <<-EOSQL
    CREATE DATABASE $database;
    GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
    ALTER SYSTEM SET listen_addresses TO '*';
    CREATE USER $PG_REP_USER REPLICATION LOGIN CONNECTION LIMIT 100 ENCRYPTED PASSWORD '$PG_REP_PASSWORD';
EOSQL
done

echo "host replication $PG_REP_USER all md5" >> $PGDATA/pg_hba.conf
echo "host replication all all md5" >> $PGDATA/pg_hba.conf