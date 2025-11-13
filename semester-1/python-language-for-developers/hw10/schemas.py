from pydantic import BaseModel, Field
from typing import Optional


class StudentBase(BaseModel):
    lastname: str = Field(..., min_length=1, max_length=100)
    firstname: str = Field(..., min_length=1, max_length=100)
    faculty: str = Field(..., min_length=1, max_length=50)
    course: str = Field(..., min_length=1, max_length=100)
    score: int = Field(..., ge=0, le=100)


class StudentCreate(StudentBase):
    pass


class StudentUpdate(BaseModel):
    lastname: Optional[str] = Field(None, min_length=1, max_length=100)
    firstname: Optional[str] = Field(None, min_length=1, max_length=100)
    faculty: Optional[str] = Field(None, min_length=1, max_length=50)
    course: Optional[str] = Field(None, min_length=1, max_length=100)
    score: Optional[int] = Field(None, ge=0, le=100)


class StudentResponse(StudentBase):
    id: int
    
    class Config:
        from_attributes = True


class AverageScoreResponse(BaseModel):
    faculty: str
    average_score: float


class StatisticsResponse(BaseModel):
    total_students: int
    unique_faculties: int
    unique_courses: int
    average_score: float

