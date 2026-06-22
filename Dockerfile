FROM postgis/postgis:16-3.4

RUN apt-get update && apt-get install -y \
    postgis \
    gdal-bin \
    && rm -rf /var/lib/apt/lists/*