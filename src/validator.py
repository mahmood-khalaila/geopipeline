import json
from pathlib import Path
from typing import Any


class GeoJSONValidationError(ValueError):
    """Raised when the input is not a supported GeoJSON FeatureCollection."""


def load_and_validate(path: Path) -> list[dict[str, Any]]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise GeoJSONValidationError(f"Cannot read valid JSON: {exc}") from exc

    if document.get("type") != "FeatureCollection":
        raise GeoJSONValidationError("Root type must be FeatureCollection")

    features = document.get("features")
    if not isinstance(features, list) or not features:
        raise GeoJSONValidationError("features must be a non-empty list")

    for index, feature in enumerate(features, start=1):
        if not isinstance(feature, dict) or feature.get("type") != "Feature":
            raise GeoJSONValidationError(f"Feature {index} has an invalid type")

        geometry = feature.get("geometry")
        if not isinstance(geometry, dict):
            raise GeoJSONValidationError(f"Feature {index} is missing geometry")
        if not geometry.get("type") or "coordinates" not in geometry:
            raise GeoJSONValidationError(f"Feature {index} has invalid geometry")

        properties = feature.get("properties")
        if not isinstance(properties, dict):
            raise GeoJSONValidationError(f"Feature {index} is missing properties")
        if not properties.get("name"):
            raise GeoJSONValidationError(f"Feature {index} is missing property 'name'")

    return features

