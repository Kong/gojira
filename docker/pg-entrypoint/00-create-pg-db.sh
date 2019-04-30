#!/bin/bash

for database in $(echo $POSTGRES_DBS | tr ',' ' '); do
  echo "Creating database $database"
  psql -U $POSTGRES_USER <<-EOSQL
    CREATE DATABASE $database;
    GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
done
