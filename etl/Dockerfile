FROM python:3.12-slim

WORKDIR /app
COPY etl/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY etl/poblarTablas1.py /app/etl/poblarTablas1.py

CMD ["python", "/app/etl/poblarTablas1.py"]
