import subprocess
from pathlib import Path


class GDALValidationError(Exception):
    pass


def inspect_with_gdal(file_path: Path) -> None:
    result = subprocess.run(
        ["ogrinfo", "-ro", "-so", "-al", str(file_path)],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        raise GDALValidationError(
            f"GDAL could not read geospatial dataset: {result.stderr}"
        )

    print("GDAL validation successful")
    print(result.stdout)