# GeoPipeline

GeoPipeline validates GeoJSON files and stores their geographic features in
PostgreSQL with the PostGIS extension. This first milestone runs locally. Later
milestones will add S3, SQS, EKS, Helm, Argo CD, and monitoring.

## Local flow

```text
GeoJSON file -> Python validator -> PostgreSQL/PostGIS
```

## Run locally

Requirements: Python 3.11+ and Docker Desktop.

```bash
cp .env.example .env
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
docker compose up -d
export DATABASE_URL=postgresql://geopipeline:geopipeline@localhost:5432/geopipeline
python -m src.process_file samples/hospitals.geojson
```

Expected result:

```text
Processing completed: inserted 2 features
```

Inspect the inserted data:

```bash
docker compose exec postgis psql -U geopipeline -d geopipeline \
  -c "SELECT id, name, ST_AsText(geometry) FROM locations;"
```

Test invalid input:

```bash
python -m src.process_file samples/invalid.geojson
```

Run unit tests:

```bash
pytest -q
```

Stop the database without deleting its volume:

```bash
docker compose down
```
