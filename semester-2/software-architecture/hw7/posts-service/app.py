import os
import datetime

from fastapi import FastAPI, HTTPException, Header, Response, Depends
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, DateTime, Text
from sqlalchemy.orm import declarative_base, sessionmaker, Session
import jwt

app = FastAPI()

DB_HOST = os.environ.get("DB_HOST")
DB_PORT = os.environ.get("DB_PORT")
DB_NAME = os.environ.get("DB_NAME")
DB_USER = os.environ.get("DB_USER")
DB_PASS = os.environ.get("DB_PASS")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

JWT_SECRET = os.environ.get("JWT_SECRET")


class Message(Base):
    __tablename__ = "messages"
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, nullable=False)
    time = Column(DateTime, nullable=False)
    message = Column(Text, nullable=False)


Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class PostRequest(BaseModel):
    message: str


@app.post("/posts")
def create_post(data: PostRequest, authorization: str = Header(), db: Session = Depends(get_db)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=400)

    token = authorization.split(" ", 1)[1]

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401)
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=400)

    user_id = payload.get("user_id")
    if not user_id:
        raise HTTPException(status_code=400)

    msg = Message(
        user_id=user_id,
        time=datetime.datetime.now(datetime.timezone.utc),
        message=data.message,
    )
    db.add(msg)
    db.commit()

    return Response(status_code=201)
