from fastapi import FastAPI
from kafka import KafkaConsumer
import psycopg2
from datetime import datetime
import json
import os
import threading
import time

app = FastAPI()

KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:pass@postgres:5432/errorsdb")
KAFKA_TOPIC = "errors"


def get_connection():
    return psycopg2.connect(DATABASE_URL)


def init_db():
    for i in range(10):
        try:
            conn = get_connection()
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS errors (
                    id      SERIAL PRIMARY KEY,
                    time    TIMESTAMP NOT NULL,
                    code    INTEGER NOT NULL,
                    message TEXT NOT NULL,
                    details TEXT NOT NULL
                )
            """)
            conn.commit()
            cur.close()
            conn.close()
            print("DB initialized successfully")
            return
        except Exception as e:
            print(f"DB not ready: {e}, retrying ({i+1}/10)...")
            time.sleep(3)
    raise Exception("Could not connect to PostgreSQL after 10 retries")


def consume():
    while True:
        try:
            consumer = KafkaConsumer(
                KAFKA_TOPIC,
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                value_deserializer=lambda v: json.loads(v.decode("utf-8")),
                auto_offset_reset="earliest",
                group_id="error-consumer-group"
            )
            break
        except Exception as e:
            print(f"Kafka not ready: {e}, retrying in 5s...")
            time.sleep(5)

    for msg in consumer:
        data = msg.value
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO errors (time, code, message, details) VALUES (%s, %s, %s, %s)",
            (datetime.utcnow(), data["code"], data["message"], data["details"])
        )
        conn.commit()
        cur.close()
        conn.close()


@app.on_event("startup")
def startup():
    init_db()
    thread = threading.Thread(target=consume, daemon=True)
    thread.start()


@app.get("/errors/")
def get_errors():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, time, code, message, details FROM errors ORDER BY time DESC")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {"id": r[0], "time": r[1], "code": r[2], "message": r[3], "details": r[4]}
        for r in rows
    ]
