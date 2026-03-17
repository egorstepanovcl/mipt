# Домашнее задание 4. Создание собственного middleware для логирования

## Информация о выполнении задания

Задание выполняется на оценку индивидуально.

## Содержание задания

### Цели задания

- Научиться создавать простой middleware для логирования основных операций.
- Уметь обрабатывать возможные ошибки, сохраняя полезную информацию для отладки
  и анализа работы приложения.

### Условия. Алгоритм выполнения задания

1. Создайте собственный **middleware** (можно оформить как декоратор функций,
   класс-обёртку или дополнительный модуль), который будет отслеживать вызовы функций,
   описанных в исходных данных ниже (отдельно для сервиса Booking и TaskManager).
2. Реализуйте **логирование**: записывайте факт вызова функций и аргументов, которые
   были переданы (`event_id`, `user_id`, `booking_id`), а также результат работы
   (успех, ошибка).
3. Если функция выбрасывает `ValueError` или `KeyError`, ваш middleware должен
   **перехватить исключение**, залогировать факт ошибки (с описанием) и снова
   «пробросить» исключение дальше.

## Исходные данные сервиса Booking

```python
# booking_service.py

import datetime

# Упрощённая «база» мероприятий
EVENTS_DB = {
    1: {"title": "Football Match", "available_seats": 10, "date": datetime.date(2025, 7, 1)},
    2: {"title": "Basketball Playoffs", "available_seats": 5, "date": datetime.date(2025, 7, 2)},
    3: {"title": "Tennis Open", "available_seats": 3, "date": datetime.date(2025, 7, 3)},
}

# Упрощённая «база» бронирований (хранилище в памяти)
BOOKINGS_DB = {}


def create_booking(event_id: int, user_id: int) -> dict:
    """
    Создаёт бронь на мероприятие event_id для пользователя user_id.
    Возвращает словарь с данными о брони или выбрасывает ValueError при ошибках.
    """
    if event_id not in EVENTS_DB:
        raise ValueError(f"Event with id={event_id} does not exist.")

    event_info = EVENTS_DB[event_id]
    if event_info["available_seats"] <= 0:
        raise ValueError("No available seats.")

    # Уменьшаем количество доступных мест
    event_info["available_seats"] -= 1

    # Генерируем booking_id (текущее время + user_id)
    booking_id = f"{int(datetime.datetime.now().timestamp())}_{user_id}"

    BOOKING_DATA = {
        "booking_id": booking_id,
        "event_id": event_id,
        "user_id": user_id,
        "title": event_info["title"],
        "date": event_info["date"],
        "created_at": datetime.datetime.now()
    }
    # Сохраняем в словарь (как базу данных)
    BOOKINGS_DB[booking_id] = BOOKING_DATA

    return BOOKING_DATA


def get_booking(booking_id: str) -> dict:
    """
    Возвращает данные о конкретной брони по booking_id.
    Поднимает KeyError, если брони нет.
    """
    return BOOKINGS_DB[booking_id]


# Пример использования (для теста)
if __name__ == "__main__":
    booking = create_booking(event_id=1, user_id=101)
    print("Created booking:", booking)

    retrieved = get_booking(booking["booking_id"])
    print("Retrieved booking:", retrieved)
```

## Исходные данные сервиса TaskManager

```python
# task_manager_service.py

import datetime

# Упрощённая «база» задач
TASKS_DB = {}


def create_task(title: str, user_id: int, due_date: datetime.date) -> dict:
    """
    Создаёт новую задачу и сохраняет её в TASKS_DB.
    Возвращает словарь с данными о задаче.
    Генерирует ValueError, если title пустой или дата просрочена.
    """
    if not title:
        raise ValueError("Task title cannot be empty.")
    if due_date < datetime.date.today():
        raise ValueError("Due date cannot be in the past.")

    task_id = len(TASKS_DB) + 1
    task_data = {
        "task_id": task_id,
        "title": title,
        "user_id": user_id,
        "due_date": due_date,
        "created_at": datetime.datetime.now(),
        "completed": False
    }
    TASKS_DB[task_id] = task_data
    return task_data


def complete_task(task_id: int) -> dict:
    """
    Отмечает задачу как завершённую.
    Поднимает KeyError, если такой задачи нет.
    """
    if task_id not in TASKS_DB:
        raise KeyError(f"Task with id={task_id} not found.")

    task_data = TASKS_DB[task_id]
    task_data["completed"] = True
    return task_data


# Пример использования (для теста)
if __name__ == "__main__":
    new_task = create_task("Finish project", user_id=101, due_date=datetime.date(2025, 8, 1))
    print("Created task:", new_task)

    updated_task = complete_task(new_task["task_id"])
    print("Updated (completed) task:", updated_task)
```

## Формат сдачи и отправка задания

- Файл с кодом в формате `.py` (например, `middleware.py` или `decorator.py`).
- Название документа в формате: **«ДЗ4_ФИО»**.

## Критерии оценивания

| Критерий оценки | Описание критерия | Баллы |
|---|---|---|
| **Настройка инструмента логирования** | Инструмент логирования настроен правильно | 3 |
| | Инструмент логирования настроен правильно, но есть ошибки в данных, которые он собирает | 1,5 |
| | Инструмент логирования не настроен | 0 |
| **Правильность лога** | Лог сделан правильно — наличие в нём `event_id`, `user_id`, `booking_id`, успех, ошибка | 3 |
| | Лог не содержит часть данных | 1,5 |
| | Лог содержит некорректные данные | 0 |
| **Настройка декоратора** | Декоратор не прерывает работу функции | 2 |
| | Декоратор прерывает работу функции | 0 |
| **Оформление кода** | Код чистый и оформленный | 2 |
| | Код имеет не более двух ошибок в оформлении | 1 |
| | Грубые ошибки в оформлении или больше двух ошибок | 0 |

**Блокирующий критерий. Несоответствие форматов сдачи**

| Условие | Результат |
|---|---|
| На проверку отправлены не все файлы, нет части файлов; **или** приложен файл другого формата, отличного от описанных в разделе «Формат сдачи и отправка задания»; **или** другие отклонения в форматах / количестве / названиях файлов на сдачу | 0 баллов за решение всего задания |

- **Максимальный балл за задание:** 10.
- **Как проверяется:** преподаватель проверит задание в течение недели после дедлайна.
