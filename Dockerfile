FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY samples/ ./samples/

CMD ["python", "-m", "src.process_file", "samples/hospitals.geojson"]