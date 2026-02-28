from fastapi import FastAPI
from pydantic import BaseModel
from kafka import KafkaProducer
import json
import os

app = FastAPI()

KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
KAFKA_TOPIC = "errors"


class ErrorRequest(BaseModel):
    code: int
    message: str
    details: str


@app.post("/errors/")
def create_error(error: ErrorRequest):
    producer = KafkaProducer(
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        value_serializer=lambda v: json.dumps(v).encode("utf-8")
    )
    message = error.model_dump()
    producer.send(KAFKA_TOPIC, value=message)
    producer.flush()
    producer.close()
    return {"status": "ok", "message": "Error sent to Kafka", "data": message}
