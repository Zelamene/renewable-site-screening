
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
