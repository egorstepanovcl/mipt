from models import StudentDatabase

def main():
    db = StudentDatabase()
    
    print("=" * 60)
    print("Загрузка данных из CSV")
    print("=" * 60)
    
    count = db.load_from_csv('students.csv')
    print(f"Загружено записей: {count}")
    
    print("\n" + "=" * 60)
    print("Список студентов по факультету (АВТФ)")
    print("=" * 60)
    students = db.get_students_by_faculty('АВТФ')
    for i, student in enumerate(students[:5], 1):
        print(f"{i}. {student.lastname} {student.firstname} - {student.course}: {student.score}")
    print(f"... всего {len(students)} студентов")
    
    print("\n" + "=" * 60)
    print("Список уникальных курсов")
    print("=" * 60)
    courses = db.get_unique_courses()
    for i, course in enumerate(courses, 1):
        print(f"{i}. {course}")
    
    print("\n" + "=" * 60)
    print("Средний балл по факультетам")
    print("=" * 60)
    avg_scores = db.get_all_faculties_avg_scores()
    for faculty, avg in avg_scores:
        print(f"{faculty}: {avg}")
    
    print("\n" + "=" * 60)
    print("Студенты с оценкой ниже 30 по курсу 'Мат. Анализ'")
    print("=" * 60)
    low_score_students = db.get_students_by_course_low_score('Мат. Анализ')
    for i, student in enumerate(low_score_students, 1):
        print(f"{i}. {student.lastname} {student.firstname} ({student.faculty}): {student.score}")
    
    print("\n" + "=" * 60)
    print("Средний балл по факультету 'ФПМИ'")
    print("=" * 60)
    avg_fpmi = db.get_average_score_by_faculty('ФПМИ')
    print(f"Средний балл: {avg_fpmi}")


if __name__ == '__main__':
    main()

