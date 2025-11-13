from fastapi import FastAPI, HTTPException, Depends, Query
from sqlalchemy.orm import Session
from typing import List
from models import StudentDatabase, Student
from schemas import (
    StudentCreate, StudentUpdate, StudentResponse,
    AverageScoreResponse, StatisticsResponse
)

app = FastAPI(title="Students API")

db = StudentDatabase()


def get_db():
    session = db.get_session()
    try:
        yield session
    finally:
        session.close()


@app.post("/students/", response_model=StudentResponse, status_code=201)
def create_student(student: StudentCreate, session: Session = Depends(get_db)):
    db_student = Student(**student.model_dump())
    session.add(db_student)
    session.commit()
    session.refresh(db_student)
    return db_student


@app.get("/students/", response_model=List[StudentResponse])
def read_students(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    session: Session = Depends(get_db)
):
    students = session.query(Student).offset(skip).limit(limit).all()
    return students


@app.get("/students/{student_id}", response_model=StudentResponse)
def read_student(student_id: int, session: Session = Depends(get_db)):
    student = session.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Студент не найден")
    return student


@app.put("/students/{student_id}", response_model=StudentResponse)
def update_student(
    student_id: int,
    student_update: StudentUpdate,
    session: Session = Depends(get_db)
):
    student = session.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Студент не найден")
    
    update_data = student_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(student, key, value)
    
    session.commit()
    session.refresh(student)
    return student


@app.delete("/students/{student_id}", status_code=204)
def delete_student(student_id: int, session: Session = Depends(get_db)):
    student = session.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Студент не найден")
    
    session.delete(student)
    session.commit()
    return None


@app.get("/students/faculty/{faculty}", response_model=List[StudentResponse])
def get_students_by_faculty(faculty: str, session: Session = Depends(get_db)):
    students = session.query(Student).filter(Student.faculty == faculty).all()
    return students


@app.get("/courses/", response_model=List[str])
def get_unique_courses(session: Session = Depends(get_db)):
    courses = session.query(Student.course).distinct().all()
    return [course[0] for course in courses]


@app.get("/faculty/{faculty}/average", response_model=AverageScoreResponse)
def get_average_score(faculty: str, session: Session = Depends(get_db)):
    from sqlalchemy import func
    
    avg_score = session.query(
        func.avg(Student.score)
    ).filter(Student.faculty == faculty).scalar()
    
    if avg_score is None:
        raise HTTPException(status_code=404, detail="Факультет не найден")
    
    return AverageScoreResponse(
        faculty=faculty,
        average_score=round(avg_score, 2)
    )


@app.get("/students/course/{course}/low-scores", response_model=List[StudentResponse])
def get_low_score_students(
    course: str,
    threshold: int = Query(30, ge=0, le=100),
    session: Session = Depends(get_db)
):
    students = session.query(Student).filter(
        Student.course == course,
        Student.score < threshold
    ).all()
    return students


@app.get("/statistics/", response_model=StatisticsResponse)
def get_statistics(session: Session = Depends(get_db)):
    from sqlalchemy import func
    
    total = session.query(Student).count()
    unique_faculties = session.query(Student.faculty).distinct().count()
    unique_courses = session.query(Student.course).distinct().count()
    avg_score = session.query(func.avg(Student.score)).scalar() or 0
    
    return StatisticsResponse(
        total_students=total,
        unique_faculties=unique_faculties,
        unique_courses=unique_courses,
        average_score=round(avg_score, 2)
    )


@app.post("/load-csv/")
def load_csv_data():
    try:
        count = db.load_from_csv('students.csv')
        return {"message": f"Загружено записей: {count}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/students/")
def delete_all_students(session: Session = Depends(get_db)):
    session.query(Student).delete()
    session.commit()
    return {"message": "Все студенты удалены"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

