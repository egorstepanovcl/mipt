from fastapi import FastAPI
import httpx
import os

app = FastAPI()

APP1_HOST = os.getenv("APP1_HOST", "app1")
APP1_PORT = os.getenv("APP1_PORT", "5000")

@app.get("/")
async def root():
    url = f"http://{APP1_HOST}:{APP1_PORT}/"
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
    return {
        "gateway": "app2",
        "response_from_app1": response.json()
    }
