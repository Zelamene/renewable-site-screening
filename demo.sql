
\echo '-------------------------------------'
\echo 'enabling PostGIS and building tables'
\echo '-------------------------------------'

CREATE EXTENSION IF NOT EXISTS postgis;

DROP TABLE IF EXISTS candidate_sites;
DROP TABLE IF EXISTS substations;
DROP TABLE IF EXISTS exclusion_zones;

-- sites to screen table
CREATE TABLE candidate_sites(
    id serial PRIMARY KEY,
    name text,
    tech text,                 -- technology type deployed at the site (e.g. solar, wind)
    geom geometry(Point, 4326) -- location stored as a Point geometry in EPSG:4326 (WGS84 lat/long)
);

-- grid connection points 

CREATE TABLE substations(
    id serial PRIMARY KEY,
    name text,
    geom geometry(Point, 4326)
);

-- no go zones for building
CREATE TABLE exclusion_zones(
    id serial PRIMARY KEY,
    name text,
    geom geometry(Polygon, 4326)
);

-- Indexes 
CREATE INDEX ON candidate_sites USING GIST(geom);
CREATE INDEX ON substations USING GIST(geom);
CREATE INDEX ON exclusion_zones USING GIST(geom);

\echo 'TABLES AND INDEXES CREATED'
\echo '--------------------------'

\echo 'SEEDING THE DB...'

INSERT INTO candidate_sites (name, tech, geom) VALUES
    ('Upington Solar', 'solar', ST_SetSRID(ST_MakePoint(21.256, -28.458), 4326)),
    ('Kimberley Solar', 'solar', ST_SetSRID(ST_MakePoint(24.762, -28.742), 4326)),
    ('Prieska Solar', 'solar', ST_SetSRID(ST_MakePoint(22.748, -29.665), 4326)),
    ('Augrabies Solar', 'solar', ST_SetSRID(ST_MakePoint(20.480, -28.400), 4326)),

    ('De Aar Wind', 'wind', ST_SetSRID(ST_MakePoint(24.012, -30.649), 4326)),
    ('Springbok Wind', 'wind', ST_SetSRID(ST_MakePoint(17.886, -29.665), 4326));


INSERT INTO substations (name, geom) VALUES
    ('Upington SS', ST_SetSRID(ST_MakePoint(21.230, -28.465), 4326)),
    ('Kimberley SS', ST_SetSRID(ST_MakePoint(23.990, -30.640), 4326)),
    ('De Aar SS', ST_SetSRID(ST_MakePoint(24.770, -28.730), 4326));

INSERT INTO exclusion_zones(name, geom) VALUES 
    ('Augrabies Conservation Block',
     ST_SetSRID(
        ST_GeomFromText('POLYGON((20.0 -28.0, 21.0 -28.0, 21.0 -28.8, 20.0 -28.8, 20.0 -28.0))'), 4326
     )
);