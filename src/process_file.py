import argparse
from pathlib import Path

from src.database import connect, initialize_database, insert_features
from src.validator import GeoJSONValidationError, load_and_validate


def process(path: Path) -> int:
    features = load_and_validate(path)
    with connect() as connection:
        initialize_database(connection)
        inserted = insert_features(connection, features)
    return inserted


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate GeoJSON and load it into PostGIS")
    parser.add_argument("file", type=Path, help="Path to a GeoJSON file")
    args = parser.parse_args()

    try:
        inserted = process(args.file)
    except GeoJSONValidationError as exc:
        raise SystemExit(f"Validation failed: {exc}") from exc

    print(f"Processing completed: inserted {inserted} features")


if __name__ == "__main__":
    main()

