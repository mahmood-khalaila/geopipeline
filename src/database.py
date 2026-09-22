import json
import os
from typing import Any

import psycopg


def connect() -> psycopg.Connection:
    database_url = os.environ.get(
        "DATABASE_URL",
        "postgresql://geopipeline:geopipeline@localhost:5432/geopipeline",
    )
    return psycopg.connect(database_url)


def initialize_database(connection: psycopg.Connection) -> None:
    with connection.cursor() as cursor:
        cursor.execute("CREATE EXTENSION IF NOT EXISTS postgis")
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS locations (
                id BIGSERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                properties JSONB NOT NULL,
                geometry geometry(Geometry, 4326) NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """
        )
    connection.commit()


def insert_features(
    connection: psycopg.Connection, features: list[dict[str, Any]]
) -> int:
    with connection.cursor() as cursor:
        for feature in features:
            properties = feature["properties"]
            cursor.execute(
                """
                INSERT INTO locations (name, properties, geometry)
                VALUES (%s, %s::jsonb, ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326))
                """,
                (
                    properties["name"],
                    json.dumps(properties),
                    json.dumps(feature["geometry"]),
                ),
            )
    connection.commit()
    return len(features)

