#!/bin/bash

pg_conf_file=/var/lib/postgresql/data/postgresql.conf

echo "\
log_statement = 'all'
log_disconnections = off
log_duration = on
log_min_duration_statement = -1
shared_preload_libraries = 'pg_stat_statements'
track_activity_query_size = 2048
pg_stat_statements.track = all
pg_stat_statements.max = 10000
password_encryption = scram-sha-256
" >>$pg_conf_file

pg_hba_conf_file=/var/lib/postgresql/data/pg_hba.conf
rm $pg_hba_conf_file
echo "\
host all all all scram-sha-256
" >>$pg_hba_conf_file

for database in $(echo $POSTGRES_DBS | tr ',' ' '); do
  echo "Creating database $database"
  psql -U $POSTGRES_USER <<-EOSQL
    CREATE DATABASE $database;
    ALTER ROLE $POSTGRES_USER WITH LOGIN PASSWORD 'secret';
    GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
done
