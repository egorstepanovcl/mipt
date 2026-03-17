"""
Домашнее задание 4. Создание собственного middleware для логирования

Запуск:
Вариант 1:
    make install
    make run
Вариант 2:
    python HW4_Stepanov_Egor_Viktorovich.py
"""

import logging
import datetime
import functools


# =============================================================================
# Настройка логгера
# =============================================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

logger = logging.getLogger("booking.middleware")


# =============================================================================
# Декоратор-middleware
# =============================================================================

def log_middleware(func):
    """
    Декоратор для логирования вызовов функций Booking-сервиса.

    Поведение:
    - Логирует имя функции и все переданные аргументы (args, kwargs).
    - При успехе логирует результат: извлекает event_id, user_id, booking_id
      из возвращаемого словаря, если они присутствуют.
    - При ValueError или KeyError логирует тип и описание ошибки,
      затем пробрасывает исключение дальше, не прерывая прочую работу.
    """
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        all_args = ", ".join(
            [repr(a) for a in args] +
            [f"{k}={v!r}" for k, v in kwargs.items()]
        )
        logger.info("CALL  | %s(%s)", func.__name__, all_args)

        try:
            result = func(*args, **kwargs)

            if isinstance(result, dict):
                log_fields = {
                    k: result[k]
                    for k in ("event_id", "user_id", "booking_id")
                    if k in result
                }
                logger.info(
                    "OK    | %s -> success | %s",
                    func.__name__,
                    log_fields if log_fields else result,
                )
            else:
                logger.info("OK    | %s -> %r", func.__name__, result)

            return result

        except (ValueError, KeyError) as exc:
            logger.error(
                "ERROR | %s | %s: %s",
                func.__name__,
                type(exc).__name__,
                exc,
            )
            raise

    return wrapper


# =============================================================================
# Booking-сервис (исходный код из задания + декоратор)
# =============================================================================

EVENTS_DB = {
    1: {"title": "Football Match",      "available_seats": 10, "date": datetime.date(2025, 7, 1)},
    2: {"title": "Basketball Playoffs", "available_seats": 5,  "date": datetime.date(2025, 7, 2)},
    3: {"title": "Tennis Open",         "available_seats": 3,  "date": datetime.date(2025, 7, 3)},
}

BOOKINGS_DB = {}


@log_middleware
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

    event_info["available_seats"] -= 1

    booking_id = f"{int(datetime.datetime.now().timestamp())}_{user_id}"

    booking_data = {
        "booking_id": booking_id,
        "event_id": event_id,
        "user_id": user_id,
        "title": event_info["title"],
        "date": event_info["date"],
        "created_at": datetime.datetime.now(),
    }
    BOOKINGS_DB[booking_id] = booking_data
    return booking_data


@log_middleware
def get_booking(booking_id: str) -> dict:
    """
    Возвращает данные о конкретной брони по booking_id.
    Поднимает KeyError, если брони нет.
    """
    return BOOKINGS_DB[booking_id]


# =============================================================================
# Демонстрация работы
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("Сценарий 1: успешное создание и получение брони")
    print("=" * 60)
    booking = create_booking(event_id=1, user_id=101)
    print(f"Создана бронь: {booking['booking_id']}\n")

    retrieved = get_booking(booking["booking_id"])
    print(f"Получена бронь: {retrieved['booking_id']}\n")

    print("=" * 60)
    print("Сценарий 2: создание брони — несуществующий event_id")
    print("=" * 60)
    try:
        create_booking(event_id=999, user_id=101)
    except ValueError as e:
        print(f"Поймано исключение: {e}\n")

    print("=" * 60)
    print("Сценарий 3: получение брони — несуществующий booking_id")
    print("=" * 60)
    try:
        get_booking("nonexistent_booking_id")
    except KeyError as e:
        print(f"Поймано исключение: {e}\n")

    print("=" * 60)
    print("Сценарий 4: создание брони — нет свободных мест")
    print("=" * 60)
    # Обнуляем места у события 3
    EVENTS_DB[3]["available_seats"] = 0
    try:
        create_booking(event_id=3, user_id=202)
    except ValueError as e:
        print(f"Поймано исключение: {e}\n")
