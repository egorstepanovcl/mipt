from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy import func
import csv
from typing import List, Optional, Dict

Base = declarative_base()


class Student(Base):
    __tablename__ = 'students'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    lastname = Column(String(100), nullable=False)
    firstname = Column(String(100), nullable=False)
    faculty = Column(String(50), nullable=False)
    course = Column(String(100), nullable=False)
    score = Column(Integer, nullable=False)
    
    def __repr__(self):
        return f"<Student('{self.lastname} {self.firstname}', faculty='{self.faculty}', course='{self.course}', score={self.score})>"


class StudentDatabase:
    
    def __init__(self, db_url: str = 'sqlite:///students.db'):
        self.engine = create_engine(db_url, echo=False)
        self.SessionLocal = sessionmaker(bind=self.engine)
        Base.metadata.create_all(self.engine)
    
    def get_session(self) -> Session:
        return self.SessionLocal()
    
    def insert_student(self, lastname: str, firstname: str, faculty: str, 
                      course: str, score: int) -> Student:
        session = self.get_session()
        try:
            student = Student(
                lastname=lastname,
                firstname=firstname,
                faculty=faculty,
                course=course,
                score=score
            )
            session.add(student)
            session.commit()
            session.refresh(student)
            return student
        finally:
            session.close()
    
    def insert_students_bulk(self, students_data: List[Dict]) -> int:
        session = self.get_session()
        try:
            session.bulk_insert_mappings(Student, students_data)
            session.commit()
            return len(students_data)
        finally:
            session.close()
    
    def select_all(self, skip: int = 0, limit: int = 100) -> List[Student]:
        session = self.get_session()
        try:
            return session.query(Student).offset(skip).limit(limit).all()
        finally:
            session.close()
    
    def select_by_id(self, student_id: int) -> Optional[Student]:
        session = self.get_session()
        try:
            return session.query(Student).filter(Student.id == student_id).first()
        finally:
            session.close()
    
    def update_student(self, student_id: int, lastname: Optional[str] = None,
                      firstname: Optional[str] = None, faculty: Optional[str] = None,
                      course: Optional[str] = None, score: Optional[int] = None) -> Optional[Student]:
        session = self.get_session()
        try:
            student = session.query(Student).filter(Student.id == student_id).first()
            if not student:
                return None
            
            if lastname is not None:
                student.lastname = lastname
            if firstname is not None:
                student.firstname = firstname
            if faculty is not None:
                student.faculty = faculty
            if course is not None:
                student.course = course
            if score is not None:
                student.score = score
            
            session.commit()
            session.refresh(student)
            return student
        finally:
            session.close()
    
    def delete_student(self, student_id: int) -> bool:
        session = self.get_session()
        try:
            student = session.query(Student).filter(Student.id == student_id).first()
            if not student:
                return False
            
            session.delete(student)
            session.commit()
            return True
        finally:
            session.close()
    
    def load_from_csv(self, csv_file: str) -> int:
        students_data = []
        
        with open(csv_file, 'r', encoding='utf-8') as file:
            csv_reader = csv.DictReader(file)
            
            for row in csv_reader:
                students_data.append({
                    'lastname': row['Фамилия'],
                    'firstname': row['Имя'],
                    'faculty': row['Факультет'],
                    'course': row['Курс'],
                    'score': int(row['Оценка'])
                })
        
        return self.insert_students_bulk(students_data)
    
    def get_students_by_faculty(self, faculty: str) -> List[Student]:
        session = self.get_session()
        try:
            return session.query(Student).filter(Student.faculty == faculty).all()
        finally:
            session.close()
    
    def get_unique_courses(self) -> List[str]:
        session = self.get_session()
        try:
            courses = session.query(Student.course).distinct().all()
            return [course[0] for course in courses]
        finally:
            session.close()
    
    def get_average_score_by_faculty(self, faculty: str) -> float:
        session = self.get_session()
        try:
            result = session.query(
                func.avg(Student.score)
            ).filter(Student.faculty == faculty).scalar()
            
            return round(result, 2) if result else 0.0
        finally:
            session.close()
    
    def get_students_by_course_low_score(self, course: str, threshold: int = 30) -> List[Student]:
        session = self.get_session()
        try:
            return session.query(Student).filter(
                Student.course == course,
                Student.score < threshold
            ).all()
        finally:
            session.close()
    
    def clear_all(self):
        session = self.get_session()
        try:
            session.query(Student).delete()
            session.commit()
        finally:
            session.close()

