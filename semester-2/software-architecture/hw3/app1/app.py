from fastapi import FastAPI
from datetime import datetime

app = FastAPI()

@app.get("/")
def root():
    return {
        "service": "app1",
        "status": "ok",
        "message": "Hello from internal service!",
        "timestamp": datetime.utcnow().isoformat()
    }
