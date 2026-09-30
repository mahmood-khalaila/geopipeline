import json
import os
from typing import Any

import boto3
import psycopg


def connect() -> psycopg.Connection:
    # Local / Docker / Kubernetes
    database_url = os.environ.get("DATABASE_URL")
    if database_url:
        return psycopg.connect(database_url)

    # AWS Lambda
    secret_arn = os.environ["DB_SECRET_ARN"]

    secrets_client = boto3.client("secretsmanager")
    response = secrets_client.get_secret_value(SecretId=secret_arn)
    secret = json.loads(response["SecretString"])

    return psycopg.connect(
        host=os.environ["DB_HOST"],
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ["DB_NAME"],
        user=secret["username"],
        password=secret["password"],
    )


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