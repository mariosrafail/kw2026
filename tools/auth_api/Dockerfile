FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN python -m pip install --no-cache-dir -r /app/requirements.txt

COPY app.py /app/app.py

ENV AUTH_API_HOST=0.0.0.0
ENV AUTH_API_PORT=8090

EXPOSE 8090

CMD ["python", "/app/app.py"]
