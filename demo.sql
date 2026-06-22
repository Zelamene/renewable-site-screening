
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
    ('Upington Solar', 'solar', ST_SetSRID(ST_MakePoint(21.256, -28.448), 4326)),
    ('Kimberley Solar', 'solar', ST_SetSRID(ST_MakePoint(24.762, -28.741), 4326)),
    ('Prieska Solar', 'solar', ST_SetSRID(ST_MakePoint(22.748, -29.664), 4326)),
    ('Augrabies Solar', 'solar', ST_SetSRID(ST_MakePoint(20.480, -28.400), 4326)),

    ('De Aar Wind', 'wind', ST_SetSRID(ST_MakePoint(24.012, -30.649), 4326)),
    ('Springbok Wind', 'wind', ST_SetSRID(ST_MakePoint(17.886, -29.665), 4326));


INSERT INTO substations (name, geom) VALUES
    ('Upington SS', ST_SetSRID(ST_MakePoint(21.230, -28.460), 4326)),
    ('De Aar SS', ST_SetSRID(ST_MakePoint(23.990, -30.640), 4326)),
    ('Kimberley SS', ST_SetSRID(ST_MakePoint(24.770, -28.730), 4326));

INSERT INTO exclusion_zones(name, geom) VALUES 
    ('Augrabies Conservation Block',
     ST_SetSRID(
        ST_GeomFromText('POLYGON((20.0 -28.0, 21.0 -28.0, 21.0 -28.8, 20.0 -28.8, 20.0 -28.0))'), 4326
     )
);

\echo 'Finish seeding.'


-- QUERIES


\echo
\echo '--------------------------------------------'
\echo ' 1. DISTANCE QUERY  -  (site, substation) pairs within 30 km'
\echo '--------------------------------------------'

SELECT s.name  AS site,
       ss.name AS substation,
       round((ST_Distance(s.geom::geography, ss.geom::geography) / 1000.0)::numeric, 1) AS distance_km
FROM candidate_sites s
JOIN substations ss
  ON ST_DWithin(s.geom::geography, ss.geom::geography, 30000) 
ORDER BY s.name, distance_km;


\echo
\echo '--------------------------------------------'
\echo ' 2. SPATIAL JOIN  -  each site to its single NEAREST substation'
\echo '--------------------------------------------'

SELECT s.name AS site,
       s.tech,
       nn.name AS nearest_substation,
       round((ST_Distance(s.geom::geography, nn.geom::geography) / 1000.0)::numeric, 1) AS distance_km
FROM candidate_sites s
CROSS JOIN LATERAL (
    SELECT ss.name, ss.geom
    FROM substations ss
    ORDER BY s.geom <-> ss.geom      -- nearest-neighbour ordering via GiST
    LIMIT 1
) AS nn
ORDER BY distance_km;


\echo
\echo '--------------------------------------------'
\echo ' 3. CONTAINMENT  -  candidate sites that fall inside a protected(no-go) zone'
\echo '--------------------------------------------'

SELECT s.name AS site,
       z.name AS exclusion_zone
FROM candidate_sites s
JOIN exclusion_zones z
  ON ST_Contains(z.geom, s.geom)
ORDER BY s.name;


\echo
\echo '--------------------------------------------'
\echo ' 4. PROJECTION  -  the SAME distance computed three ways'
\echo '--------------------------------------------'

WITH pair AS (
    SELECT (SELECT geom FROM candidate_sites WHERE name = 'Upington Solar') AS a,
           (SELECT geom FROM substations     WHERE name = 'Upington SS')    AS b
)
SELECT
    round(ST_Distance(a, b)::numeric, 4)                                            AS raw_4326_degrees,
    round((ST_Distance(a::geography, b::geography))::numeric, 1)                    AS geography_metres,
    round(ST_Distance(ST_Transform(a, 32734), ST_Transform(b, 32734))::numeric, 1) AS utm34s_metres
FROM pair;
-- EPSG:32734 = WGS84 / UTM zone 34S, the metre-based zone covering aprox 21 deg E


\echo
\echo '--------------------------------------------'
\echo ' 5.  a simple screening verdict per site'
\echo '--------------------------------------------'

SELECT
    s.name AS site,
    s.tech,
    EXISTS (SELECT 1 FROM substations ss
            WHERE ST_DWithin(s.geom::geography, ss.geom::geography, 30000)) AS grid_within_30km,
    EXISTS (SELECT 1 FROM exclusion_zones z
            WHERE ST_Contains(z.geom, s.geom))                             AS in_exclusion_zone,
    CASE
        WHEN EXISTS (SELECT 1 FROM exclusion_zones z WHERE ST_Contains(z.geom, s.geom))
            THEN 'REJECT - protected land'
        WHEN NOT EXISTS (SELECT 1 FROM substations ss
                         WHERE ST_DWithin(s.geom::geography, ss.geom::geography, 30000))
            THEN 'REVIEW - no grid within 30 km'
        ELSE 'PASS - screenable'
    END AS verdict
FROM candidate_sites s
ORDER BY verdict, s.name;

\echo
\echo 'Done.'