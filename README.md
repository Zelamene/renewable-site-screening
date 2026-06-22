# Renewable-energy site screening

A small PostGIS project that runs a first-pass spatial screen for candidate solar and wind sites in South Africa — checking grid proximity and protected-land conflicts, then tagging each site with its real municipality.

> Built to reinforce PostGIS / spatial-SQL fundamentals — a focused learning exercise, not a production system. See [Data and limitations](#data-and-limitations).

## What it does

Renewable siting needs two early checks: is there a nearby grid connection, and is the land clear of protected areas? This project runs that screen against South African data — candidate sites, substations, and exclusion zones — and outputs a `PASS / REJECT / REVIEW` verdict per site, each tagged with its real municipality (loaded from an official shapefile).

## What it covers

| Step | Concept | Query |
|---|---|---|
| 0 | Typed geometry + GiST indexes | `geometry(Point/Polygon, 4326)` |
| 1 | Distance | `ST_DWithin` on `geography` — substations within 30 km |
| 2 | Nearest-neighbour join | `LATERAL` + `<->` KNN operator |
| 3 | Containment | `ST_Contains` — sites inside exclusion zones |
| 4 | Projection vs. geography | same distance in degrees vs. `geography` vs. UTM 34S |
| 5 | Composite verdict | `PASS / REJECT / REVIEW` per site |

## Run it

```bash
docker compose up -d
./run.sh
```

Seeds the demo data, loads the real Municipal Demarcation Board boundary shapefile, and prints each site with its municipality and verdict.

`docker compose down` to tear down — there's no persistent volume, so `run.sh` re-seeds clean every run.

## Sample output

```
      site       | tech  | municipality  |            verdict
-----------------+-------+---------------+-------------------------------
 De Aar Wind     | wind  | Emthanjeni    | PASS - screenable
 Augrabies Solar | solar | Kai !Garib    | REJECT - protected land
 Prieska Solar   | solar | Siyathemba    | REVIEW - no grid within 30 km
```

**Why coordinate systems matter (step 4):** the same Upington site-to-substation distance, computed three ways:

```
 raw_4326_degrees | geography_metres | utm34s_metres
------------------+------------------+---------------
           0.0286 |           2873.0 |        2871.8
```

Raw `ST_Distance` on lon/lat (EPSG:4326) returns degrees, not km. Casting to `geography` or transforming to a metre-based CRS (UTM 34S) gives the real answer — the two correct methods agree to ~1m.

## Data and limitations

- Town coordinates are real and approximate; municipal boundaries are real (MDB 2018, via demarcation.org.za).
- **Substation locations and the exclusion zone are synthetic** — not official Eskom or SANParks data. They exist to make the queries meaningful, not to model the real grid or real protected areas.
- The exclusion zone is a simplified rectangle, not an actual park boundary.

## Possible extensions

Screen against more real layers (grid lines, land use, terrain/slope), not just municipal boundaries.