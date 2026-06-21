# starts postgis in docker, sun the demo script

set -e

docker run --name pg-gis -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgis/postgis:16-3.4

echo "waiting for PostGIS to accept connections..."
until docker exec pg-gis pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done

docker exec -i pg-gis psql -U postgres < demo.sql
