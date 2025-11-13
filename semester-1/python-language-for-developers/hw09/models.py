from sqlalchemy import create_engine, Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy import func
import csv
from typing import List, Tuple, Dict

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
    
    def select_all(self) -> List[Student]:
        session = self.get_session()
        try:
            return session.query(Student).all()
        finally:
            session.close()
    
    def select_by_id(self, student_id: int) -> Student:
        session = self.get_session()
        try:
            return session.query(Student).filter(Student.id == student_id).first()
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
    
    def get_all_faculties_avg_scores(self) -> List[Tuple[str, float]]:
        session = self.get_session()
        try:
            results = session.query(
                Student.faculty,
                func.avg(Student.score).label('avg_score')
            ).group_by(Student.faculty).all()
            
            return [(faculty, round(avg, 2)) for faculty, avg in results]
        finally:
            session.close()
    
    def get_statistics(self) -> Dict:
        session = self.get_session()
        try:
            total_students = session.query(Student).count()
            avg_score = session.query(func.avg(Student.score)).scalar()
            max_score = session.query(func.max(Student.score)).scalar()
            min_score = session.query(func.min(Student.score)).scalar()
            
            return {
                'total_students': total_students,
                'average_score': round(avg_score, 2) if avg_score else 0,
                'max_score': max_score,
                'min_score': min_score
            }
        finally:
            session.close()
    
    def clear_all(self):
        session = self.get_session()
        try:
            session.query(Student).delete()
            session.commit()
        finally:
            session.close()

