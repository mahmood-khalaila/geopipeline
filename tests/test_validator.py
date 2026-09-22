import json

import pytest

from src.validator import GeoJSONValidationError, load_and_validate

#tmp geofile 
def write_geojson(tmp_path, document):
    path = tmp_path / "input.geojson"
    path.write_text(json.dumps(document), encoding="utf-8")
    return path

#check validator
def test_accepts_valid_feature_collection(tmp_path):
    path = write_geojson(
        tmp_path,
        {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {"name": "Rambam"},
                    "geometry": {"type": "Point", "coordinates": [34.985, 32.834]},
                }
            ],
        },
    )

    features = load_and_validate(path)

    assert len(features) == 1
    assert features[0]["properties"]["name"] == "Rambam"


def test_rejects_feature_without_geometry(tmp_path):
    path = write_geojson(
        tmp_path,
        {
            "type": "FeatureCollection",
            "features": [
                {"type": "Feature", "properties": {"name": "Broken location"}}
            ],
        },
    )

    with pytest.raises(GeoJSONValidationError, match="missing geometry"):
        load_and_validate(path)


def test_rejects_feature_without_name(tmp_path):
    path = write_geojson(
        tmp_path,
        {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {},
                    "geometry": {"type": "Point", "coordinates": [1, 2]},
                }
            ],
        },
    )

    with pytest.raises(GeoJSONValidationError, match="missing property 'name'"):
        load_and_validate(path)

