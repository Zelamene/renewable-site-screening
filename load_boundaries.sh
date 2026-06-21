#!/usr/bin/env bash

# Load the MDB Local Municipalities 2018 shapefile into PostGIS and standardise
# the municipality-name column. Values are fixed for this dataset:

set -euo pipefail

CONTAINER="${CONTAINER:-pg-gis}"
LOCAL_DIR="${LOCAL_DIR:-./boundary_data}"
SHP="${SHP:-LocalMunicipalities2018_Final.shp}"
TABLE="${TABLE:-municipalities}"
NAME_COL="${NAME_COL:-municname}"
PGUSER_="${PGUSER_:-postgres}"

# Run a psql invocation
run_sql() {
  if [ -n "$CONTAINER" ]; then
    docker exec -i "$CONTAINER" psql -U "$PGUSER_" "$@"
  else
    psql "$@"
  fi
}

echo ">> loading $SHP -> table '$TABLE'  (reproject 32735->4326, UTF-8, GiST index)"
if [ -n "$CONTAINER" ]; then
  docker exec "$CONTAINER" rm -rf /data
  docker cp "$LOCAL_DIR" "$CONTAINER":/data
  docker exec "$CONTAINER" bash -c "set -eo pipefail
    psql -U '$PGUSER_' -q -c 'DROP TABLE IF EXISTS $TABLE;'
    shp2pgsql -I -s 32735:4326 -W UTF-8 '/data/$SHP' '$TABLE' | psql -U '$PGUSER_' -q"
else
  psql -q -c "DROP TABLE IF EXISTS $TABLE;"
  shp2pgsql -I -s 32735:4326 -W UTF-8 "$LOCAL_DIR/$SHP" "$TABLE" | psql -q
fi

echo ">> standardising name column -> municipality"
if run_sql -v ON_ERROR_STOP=1 -c \
     "ALTER TABLE $TABLE RENAME COLUMN $NAME_COL TO municipality;" 2>/dev/null; then
  echo "   renamed $NAME_COL -> municipality"
else
  echo "   column '$NAME_COL' not found. Columns in $TABLE:"
  run_sql -c "\\d $TABLE"
  echo "   -> set NAME_COL to the name column shown above and re-run."
  exit 1
fi

echo ">> loaded:"
run_sql -c "SELECT count(*) AS municipalities FROM $TABLE;"

echo
echo ">> next, run the boundary queries (after demo.sql):"
if [ -n "$CONTAINER" ]; then
  echo "   docker exec -i $CONTAINER psql -U $PGUSER_ < boundaries.sql"
else
  echo "   psql < boundaries.sql"
fi
