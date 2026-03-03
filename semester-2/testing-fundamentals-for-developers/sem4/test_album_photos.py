import time
import re
import pytest
import requests

BASE_URL = "https://jsonplaceholder.typicode.com"
ALBUM_ID = 2
ENDPOINT = f"{BASE_URL}/albums/{ALBUM_ID}/photos"

EXPECTED_PHOTO_COUNT = 50
EXPECTED_ID_MIN = 51
EXPECTED_ID_MAX = 100
EXPECTED_KEYS = {"albumId", "id", "title", "url", "thumbnailUrl"}
MAX_RESPONSE_TIME = 0.5

PLACEHOLDER_URL_PATTERN = re.compile(
    r"^https://via\.placeholder\.com/\d+/[0-9a-fA-F]+$"
)


@pytest.fixture(scope="module")
def api_response():
    start = time.time()
    response = requests.get(ENDPOINT)
    elapsed = time.time() - start
    return response, elapsed


@pytest.fixture(scope="module")
def photos(api_response):
    response, _ = api_response
    return response.json()


# ─────────────────────────────────────────────
# 1. Статус ответа
# ─────────────────────────────────────────────
class TestStatusCode:
    def test_status_200(self, api_response):
        response, _ = api_response
        assert response.status_code == 200, (
            f"Ожидался статус 200, получен {response.status_code}"
        )


# ─────────────────────────────────────────────
# 2. Формат данных
# ─────────────────────────────────────────────
class TestDataFormat:
    def test_response_is_list(self, photos):
        assert isinstance(photos, list), "Ответ должен быть списком (JSON array)"

    def test_each_item_is_dict(self, photos):
        for i, photo in enumerate(photos):
            assert isinstance(photo, dict), f"Элемент [{i}] не является объектом"

    def test_id_is_integer_in_expected_range(self, photos):
        for photo in photos:
            assert isinstance(photo["id"], int), (
                f"id должен быть целым числом, получено: {photo['id']!r}"
            )
            assert EXPECTED_ID_MIN <= photo["id"] <= EXPECTED_ID_MAX, (
                f"id={photo['id']} вне ожидаемого диапазона "
                f"[{EXPECTED_ID_MIN}, {EXPECTED_ID_MAX}]"
            )

    def test_album_id_is_positive_integer(self, photos):
        for photo in photos:
            assert isinstance(photo["albumId"], int) and photo["albumId"] > 0, (
                f"albumId должен быть целым числом > 0, получено: {photo['albumId']}"
            )

    def test_title_is_non_empty_string(self, photos):
        for photo in photos:
            assert isinstance(photo["title"], str) and len(photo["title"]) > 0, (
                f"title должен быть непустой строкой, получено: {photo['title']!r}"
            )

    def test_url_matches_placeholder_pattern(self, photos):
        for photo in photos:
            assert PLACEHOLDER_URL_PATTERN.match(photo["url"]), (
                f"url не соответствует ожидаемому формату via.placeholder.com, "
                f"получено: {photo['url']!r}"
            )

    def test_thumbnail_url_matches_placeholder_pattern(self, photos):
        for photo in photos:
            assert PLACEHOLDER_URL_PATTERN.match(photo["thumbnailUrl"]), (
                f"thumbnailUrl не соответствует ожидаемому формату via.placeholder.com, "
                f"получено: {photo['thumbnailUrl']!r}"
            )

    def test_content_type_is_json(self, api_response):
        response, _ = api_response
        assert "application/json" in response.headers.get("Content-Type", ""), (
            "Content-Type должен содержать application/json"
        )


# ─────────────────────────────────────────────
# 3. Корректность данных
# ─────────────────────────────────────────────
class TestDataCorrectness:
    def test_no_extra_fields(self, photos):
        for i, photo in enumerate(photos):
            extra = set(photo.keys()) - EXPECTED_KEYS
            assert not extra, f"Элемент [{i}] содержит лишние поля: {extra}"

    def test_no_missing_fields(self, photos):
        for i, photo in enumerate(photos):
            missing = EXPECTED_KEYS - set(photo.keys())
            assert not missing, (
                f"Элемент [{i}] не содержит обязательные поля: {missing}"
            )

    def test_photo_count(self, photos):
        assert len(photos) == EXPECTED_PHOTO_COUNT, (
            f"Ожидалось {EXPECTED_PHOTO_COUNT} фото, получено {len(photos)}"
        )

    def test_all_photos_belong_to_album(self, photos):
        for photo in photos:
            assert photo["albumId"] == ALBUM_ID, (
                f"Фото id={photo['id']} имеет albumId={photo['albumId']}, "
                f"ожидался {ALBUM_ID}"
            )

    def test_ids_are_unique(self, photos):
        ids = [photo["id"] for photo in photos]
        assert len(ids) == len(set(ids)), "Обнаружены дублирующиеся id"

    def test_ids_cover_full_expected_range(self, photos):
        ids = set(photo["id"] for photo in photos)
        expected_ids = set(range(EXPECTED_ID_MIN, EXPECTED_ID_MAX + 1))
        assert ids == expected_ids, (
            f"Отсутствующие id: {expected_ids - ids}, "
            f"лишние id: {ids - expected_ids}"
        )


# ─────────────────────────────────────────────
# 4. Скорость ответа
# ─────────────────────────────────────────────
class TestResponseTime:
    def test_response_time_under_threshold(self, api_response):
        _, elapsed = api_response
        assert elapsed < MAX_RESPONSE_TIME, (
            f"Время ответа {elapsed:.3f}с превышает порог {MAX_RESPONSE_TIME}с"
        )

