import tempfile
import urllib.parse
from pathlib import Path

import boto3

from src.validator import load_and_validate
from src.database import connect, initialize_database, insert_features


s3 = boto3.client("s3")


def handler(event, context):
    record = event["Records"][0]

    bucket = record["s3"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

    print(f"Processing s3://{bucket}/{key}")

    with tempfile.NamedTemporaryFile(suffix=".geojson") as tmp:
        s3.download_file(bucket, key, tmp.name)

        features = load_and_validate(Path(tmp.name))

        with connect() as connection:
            initialize_database(connection)
            inserted = insert_features(connection, features)

    print(f"Processing completed: inserted {inserted} features")

    return {
        "statusCode": 200,
        "inserted": inserted,
    }