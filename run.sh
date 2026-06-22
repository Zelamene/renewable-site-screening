#!/usr/bin/env bash
set -euo pipefail

CONTAINER="pg-gis"

echo "Waiting for DB..."
until docker exec "$CONTAINER" pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done

echo "schema + seed"
docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres < demo.sql

echo "boundary load"
docker exec "$CONTAINER" bash -c '
set -eo pipefail
psql -U postgres -c "DROP TABLE IF EXISTS municipalities;"
shp2pgsql -I -s 32735:4326 -W UTF-8 \
  /data/LocalMunicipalities2018_Final.shp municipalities \
| psql -U postgres
psql -U postgres -c "ALTER TABLE municipalities RENAME COLUMN municname TO municipality;" 2>/dev/null || true
'

echo "FINAL QUERY  -  each site, its real municipality, and the screening verdict"
docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres <<'SQL'
SELECT
    s.name AS site,
    s.tech,
    m.municipality,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM exclusion_zones z
            WHERE ST_Contains(z.geom, s.geom)
        )
        THEN 'REJECT - protected land'
        WHEN NOT EXISTS (
            SELECT 1 FROM substations ss
            WHERE ST_DWithin(s.geom::geography, ss.geom::geography, 30000)
        )
        THEN 'REVIEW - no grid within 30 km'
        ELSE 'PASS - screenable'
    END AS verdict
FROM candidate_sites s
LEFT JOIN municipalities m ON ST_Contains(m.geom, s.geom)
ORDER BY verdict, s.name;
SQL

echo "DONE"