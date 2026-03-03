from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
import asyncpg
import os
import asyncio

app = FastAPI()

DB_HOST = os.getenv("DB_HOST", "db")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "notesdb")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASS", "postgres")

class NoteIn(BaseModel):
    text: str

class Note(BaseModel):
    id: int
    text: str
    created_at: datetime

async def get_conn():
    return await asyncpg.connect(
        host=DB_HOST, port=int(DB_PORT),
        database=DB_NAME, user=DB_USER, password=DB_PASS
    )

@app.on_event("startup")
async def startup():
    for attempt in range(10):
        try:
            conn = await get_conn()
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS notes (
                    id SERIAL PRIMARY KEY,
                    text TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT NOW()
                )
            """)
            await conn.close()
            return
        except Exception as e:
            print(f"DB not ready (attempt {attempt + 1}/10): {e}")
            await asyncio.sleep(3)
    raise RuntimeError("Could not connect to database after 10 attempts")

@app.post("/notes", response_model=Note, status_code=201)
async def create_note(note: NoteIn):
    conn = await get_conn()
    row = await conn.fetchrow(
        "INSERT INTO notes (text) VALUES ($1) RETURNING id, text, created_at",
        note.text
    )
    await conn.close()
    return dict(row)

@app.get("/notes", response_model=list[Note])
async def get_notes():
    conn = await get_conn()
    rows = await conn.fetch("SELECT id, text, created_at FROM notes ORDER BY id")
    await conn.close()
    return [dict(r) for r in rows]

