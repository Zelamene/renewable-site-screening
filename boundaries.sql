--  Boundary queries - run against municipal polygons that were
--  loaded from a shapefile with shp2pgsql

\echo '-------------------------------------------'
\echo ' Loaded boundary layer'
\echo '--------------------------------------------'
SELECT count(*) AS municipalities_loaded FROM municipalities;

\echo '--------------------------------------------'
\echo ' POINT-IN-POLYGON  which municipality is each site in?'
\echo '-------------------------------------------'
SELECT s.name AS site,
       s.tech,
       m.municipality
FROM candidate_sites s
LEFT JOIN municipalities m ON ST_Contains(m.geom, s.geom)
ORDER BY s.name;


\echo '--------------------------------------------'
\echo ' candidate sites per municipality'
\echo '--------------------------------------------'
SELECT m.municipality,
       count(s.id) AS site_count
FROM municipalities m
LEFT JOIN candidate_sites s ON ST_Contains(m.geom, s.geom)
GROUP BY m.municipality
ORDER BY site_count DESC, m.municipality;

\echo
\echo 'Done.'
