"""
Домашнее задание 3. Проведение юнит-тестов с помощью PyTest

Запуск:
Вариант 1:
    make install
    make test
Вариант 2:
    pip install pytest
    pytest test_booking_service_Stepanov_Egor_Viktorovich.py -v
"""

import re
import smtplib
import pytest
from datetime import date, timedelta
from unittest.mock import patch, MagicMock


# =============================================================================
# Тестируемые функции
# =============================================================================

def calc_price(base_price: float, discount: float, count: int) -> float:
    """
    Рассчитывает итоговую сумму за count билетов с учётом базовой цены и скидки
    discount — процент скидки (0..100)
    Raises ValueError при недопустимых аргументах
    """
    if base_price < 0:
        raise ValueError("base_price cannot be negative.")
    if not (0 <= discount <= 100):
        raise ValueError("discount must be between 0 and 100.")
    if count < 0:
        raise ValueError("count cannot be negative.")
    discounted = base_price * (1 - discount / 100)
    return round(discounted * count, 2)


def check_availability(event_id: int, seats_requested: int, db_getter) -> bool:
    """
    Проверяет наличие свободных мест через db_getter(event_id) -> int
    Возвращает True, если мест достаточно, иначе False
    Raises ValueError при некорректных аргументах
    """
    if seats_requested <= 0:
        raise ValueError("seats_requested must be positive.")
    available = db_getter(event_id)
    return available >= seats_requested


PROMO_REPO = {
    "SUMMER10": {"discount": 10, "expires": date(2099, 12, 31), "uses_left": 5},
    "EXPIRED":  {"discount": 20, "expires": date(2000, 1, 1),  "uses_left": 5},
    "NOLIMIT":  {"discount": 15, "expires": date(2099, 12, 31), "uses_left": 0},
}


def apply_promo_code(order_id: int, promo_code: str, repo=None) -> bool:
    """
    Применяет промокод к заказу. repo — словарь промокодов (по умолчанию PROMO_REPO)
    Возвращает True при успехе, False при невалидном/истёкшем/исчерпанном коде
    """
    if repo is None:
        repo = PROMO_REPO
    promo = repo.get(promo_code)
    if promo is None:
        return False
    if promo["expires"] < date.today():
        return False
    if promo["uses_left"] <= 0:
        return False
    promo["uses_left"] -= 1
    return True


def generate_booking_ref(user_id: int, event_id: int) -> str:
    """
    Генерирует уникальный референс бронирования вида BOOK-<user_id>-<event_id>-<suffix>
    Raises ValueError при некорректных id
    """
    import uuid
    if user_id <= 0 or event_id <= 0:
        raise ValueError("user_id and event_id must be positive integers.")
    suffix = uuid.uuid4().hex[:8].upper()
    return f"BOOK-{user_id}-{event_id}-{suffix}"


def send_notification_email(email: str, booking_details: dict, smtp_client=None) -> bool:
    """
    Отправляет уведомление на email. smtp_client — объект с методом sendmail()
    Возвращает True при успехе, False при ошибке SMTP или невалидном email
    """
    if not re.match(r"[^@]+@[^@]+\.[^@]+", email):
        return False
    try:
        if smtp_client is None:
            raise smtplib.SMTPException("No SMTP client provided.")
        smtp_client.sendmail(
            "noreply@booking.com",
            email,
            f"Subject: Booking Confirmation\n\n{booking_details}"
        )
        return True
    except smtplib.SMTPException:
        return False


# =============================================================================
# Фикстуры
# =============================================================================

@pytest.fixture
def booking_details():
    return {
        "booking_id": "ABC123",
        "event_id": 1,
        "user_id": 101,
        "title": "Football Match",
        "date": date(2026, 7, 1),
    }


@pytest.fixture
def mock_db_with_seats():
    """Возвращает db_getter, у которого для event_id=1 есть 10 мест"""
    def getter(event_id):
        db = {1: 10, 2: 0, 3: 3}
        return db.get(event_id, 0)
    return getter


@pytest.fixture
def fresh_promo_repo():
    """Свежий репозиторий промокодов для каждого теста"""
    return {
        "VALID10":  {"discount": 10, "expires": date(2099, 12, 31), "uses_left": 3},
        "EXPIRED":  {"discount": 20, "expires": date(2000, 1, 1),  "uses_left": 5},
        "NOLIMIT":  {"discount": 15, "expires": date(2099, 12, 31), "uses_left": 0},
    }


@pytest.fixture
def mock_smtp():
    """Мок SMTP-клиента с рабочим методом sendmail"""
    client = MagicMock()
    client.sendmail.return_value = {}
    return client


@pytest.fixture
def broken_smtp():
    """Мок SMTP-клиента, который выбрасывает SMTPException"""
    client = MagicMock()
    client.sendmail.side_effect = smtplib.SMTPException("Server unavailable")
    return client


# =============================================================================
# 1. calc_price
# =============================================================================

class TestCalcPrice:

    # --- Позитивные ---

    @pytest.mark.parametrize("base_price,discount,count,expected", [
        (1000.0, 0.0,   2, 2000.0),   # без скидки
        (1000.0, 10.0,  3, 2700.0),   # скидка 10%
        (500.0,  100.0, 5, 0.0),      # скидка 100% -> сумма 0
        (0.0,    50.0,  10, 0.0),     # нулевая цена
    ])
    def test_calc_price_positive(self, base_price, discount, count, expected):
        """Корректные входные данные — результат совпадает с ожидаемым"""
        assert calc_price(base_price, discount, count) == expected

    def test_calc_price_zero_tickets(self):
        """0 билетов -> итог 0"""
        assert calc_price(1000.0, 10.0, 0) == 0.0

    # --- Негативные ---

    def test_calc_price_negative_base_price(self):
        """Отрицательная базовая цена -> ValueError"""
        with pytest.raises(ValueError, match="base_price"):
            calc_price(-100.0, 10.0, 2)

    def test_calc_price_negative_discount(self):
        """Отрицательная скидка -> ValueError"""
        with pytest.raises(ValueError, match="discount"):
            calc_price(1000.0, -5.0, 2)

    def test_calc_price_discount_over_100(self):
        """Скидка > 100% -> ValueError"""
        with pytest.raises(ValueError, match="discount"):
            calc_price(1000.0, 150.0, 2)

    def test_calc_price_negative_count(self):
        """Отрицательное количество билетов -> ValueError"""
        with pytest.raises(ValueError, match="count"):
            calc_price(1000.0, 10.0, -1)


# =============================================================================
# 2. check_availability
# =============================================================================

class TestCheckAvailability:

    # --- Позитивные ---

    def test_enough_seats_returns_true(self, mock_db_with_seats):
        """Запрашиваем 5 мест, доступно 10 -> True"""
        assert check_availability(1, 5, mock_db_with_seats) is True

    def test_exact_seats_returns_true(self, mock_db_with_seats):
        """Запрашиваем ровно столько, сколько есть -> True"""
        assert check_availability(3, 3, mock_db_with_seats) is True

    # --- Негативные ---

    def test_no_seats_returns_false(self, mock_db_with_seats):
        """Мест нет (event_id=2) -> False"""
        assert check_availability(2, 1, mock_db_with_seats) is False

    def test_more_than_available_returns_false(self, mock_db_with_seats):
        """Запрашиваем 15, доступно 10 -> False"""
        assert check_availability(1, 15, mock_db_with_seats) is False

    def test_zero_seats_requested_raises(self, mock_db_with_seats):
        """seats_requested=0 -> ValueError"""
        with pytest.raises(ValueError, match="seats_requested"):
            check_availability(1, 0, mock_db_with_seats)

    def test_negative_seats_requested_raises(self, mock_db_with_seats):
        """seats_requested < 0 -> ValueError"""
        with pytest.raises(ValueError):
            check_availability(1, -3, mock_db_with_seats)


# =============================================================================
# 3. apply_promo_code
# =============================================================================

class TestApplyPromoCode:

    # --- Позитивные ---

    def test_valid_promo_returns_true(self, fresh_promo_repo):
        """Валидный промокод -> True, uses_left уменьшается"""
        result = apply_promo_code(1, "VALID10", repo=fresh_promo_repo)
        assert result is True
        assert fresh_promo_repo["VALID10"]["uses_left"] == 2

    def test_promo_decrements_uses(self, fresh_promo_repo):
        """Применяем промокод дважды — uses_left уменьшается с 3 до 1"""
        apply_promo_code(1, "VALID10", repo=fresh_promo_repo)
        apply_promo_code(2, "VALID10", repo=fresh_promo_repo)
        assert fresh_promo_repo["VALID10"]["uses_left"] == 1

    # --- Негативные ---

    def test_expired_promo_returns_false(self, fresh_promo_repo):
        """Истёкший промокод -> False"""
        assert apply_promo_code(1, "EXPIRED", repo=fresh_promo_repo) is False

    def test_exhausted_promo_returns_false(self, fresh_promo_repo):
        """Исчерпанный лимит (uses_left=0) -> False"""
        assert apply_promo_code(1, "NOLIMIT", repo=fresh_promo_repo) is False

    def test_unknown_promo_returns_false(self, fresh_promo_repo):
        """Несуществующий промокод -> False"""
        assert apply_promo_code(1, "DOESNOTEXIST", repo=fresh_promo_repo) is False

    def test_empty_promo_returns_false(self, fresh_promo_repo):
        """Пустая строка промокода -> False"""
        assert apply_promo_code(1, "", repo=fresh_promo_repo) is False


# =============================================================================
# 4. generate_booking_ref
# =============================================================================

class TestGenerateBookingRef:

    # --- Позитивные ---

    def test_ref_format(self):
        """Референс соответствует формату BOOK-<user_id>-<event_id>-<8 hex chars>"""
        ref = generate_booking_ref(101, 5)
        assert re.match(r"^BOOK-101-5-[0-9A-F]{8}$", ref), f"Unexpected format: {ref}"

    def test_refs_are_unique(self):
        """Два вызова с одинаковыми id возвращают разные строки"""
        ref1 = generate_booking_ref(101, 5)
        ref2 = generate_booking_ref(101, 5)
        assert ref1 != ref2

    def test_ref_contains_user_and_event_ids(self):
        """Референс содержит оба переданных id"""
        ref = generate_booking_ref(42, 7)
        assert "42" in ref
        assert "7" in ref

    # --- Негативные ---

    def test_zero_user_id_raises(self):
        """user_id=0 -> ValueError"""
        with pytest.raises(ValueError, match="positive"):
            generate_booking_ref(0, 5)

    def test_negative_event_id_raises(self):
        """event_id < 0 -> ValueError"""
        with pytest.raises(ValueError, match="positive"):
            generate_booking_ref(101, -1)

    def test_both_zero_raises(self):
        """Оба аргумента 0 -> ValueError"""
        with pytest.raises(ValueError):
            generate_booking_ref(0, 0)


# =============================================================================
# 5. send_notification_email
# =============================================================================

class TestSendNotificationEmail:

    # --- Позитивные ---

    def test_success_returns_true(self, mock_smtp, booking_details):
        """Корректный email + рабочий SMTP -> True"""
        result = send_notification_email("user@example.com", booking_details, mock_smtp)
        assert result is True

    def test_sendmail_called_with_correct_recipient(self, mock_smtp, booking_details):
        """sendmail вызывается с правильным адресом получателя"""
        send_notification_email("user@example.com", booking_details, mock_smtp)
        args = mock_smtp.sendmail.call_args[0]
        assert args[1] == "user@example.com"

    # --- Негативные ---

    def test_smtp_failure_returns_false(self, broken_smtp, booking_details):
        """SMTP выбрасывает исключение -> функция возвращает False"""
        result = send_notification_email("user@example.com", booking_details, broken_smtp)
        assert result is False

    def test_invalid_email_returns_false(self, mock_smtp, booking_details):
        """Невалидный email -> False, sendmail не вызывается"""
        result = send_notification_email("not-an-email", booking_details, mock_smtp)
        assert result is False
        mock_smtp.sendmail.assert_not_called()

    def test_no_smtp_client_returns_false(self, booking_details):
        """Без SMTP-клиента -> False"""
        result = send_notification_email("user@example.com", booking_details, None)
        assert result is False

