# Итоговое задание

| Поле | Значение |
| :-- | :-- |
| **Дисциплина** | Реляционные базы данных |
| **Тема** | Проектирование баз данных |
| **Время выполнения** | 6 часов   |
| **Дедлайн** | 15.04.2026 |

## Цель задания

Научиться реализовывать:
- физическую и логическую схемы базы данных на основе спроектированной концептуальной схемы;
- функционал базы данных.

## Инструменты

- PostgreSQL

## Правила приёма работы

- Выполните работу по пунктам из описания задания.
- Прикрепите в LMS **один файл** резервной копии в формате `.backup`.

## Критерии оценки

**Максимум:** 10 баллов

**Проходной балл:** 4

| Критерий | Баллы |
|---|---|
| Реализована логическая и физическая схемы в соответствии с требованиями бизнес-заказчика. Таблицы должны быть не ниже 3 НФ. | 2 |
| Реализованы процедуры `insert_test_data(value)` и `erase_test_data()` | 2 |
| Реализованы триггер и функция `rating_change()` | 1 |
| Реализована функция `get_statistic()` | 1 |
| Реализовано представление `how_much_money` | 1 |
| Реализация пользователя, резервной копии, типов данных | 1 |
| Реализована процедура `courier_salary()` | 1 |
| Реализация процедуры `add_product(атрибуты таблицы product)` | 1 |

> ⚠️ **Важно:** должен быть реализован **полностью весь функционал**. Например, если будет реализовано всё верно, но будет отсутствовать процедура `insert_test_data(value)`, то по работе будет **0 баллов**, а не 8 — без неё невозможно протестировать функционал, нагрузки, права доступа и т.д.

## Чек-лист самопроверки

Задание считается выполненным, если:
- реализованы пункты в соответствии с описанием задания;
- прикреплён один файл резервной копии в формате `.backup`;
- выполненное задание доступно в файле.

## Описание задания

**Задача:** реализовать логическую и физическую схемы базы данных, функционал по генерации тестовых данных и функционал по автоматизации для сервиса по онлайн-заказу еды.

### 1. Создание схемы

Локально в базе данных `postgres` создайте схему в формате: `фамилия_на_латинице_в_нижнем_регистре_food`

Пример: `khashchanov_food`

В этой схеме нужно создать таблицы, типы данных, функции, процедуры и иные необходимые объекты.

### 2. Физическая схема

Реализуйте физическую схему на основе концептуальной схемы из файла `Концептуальная схема МФТИ ИТ 2026.docx`:
- все идентификаторы — тип `uuid`;
- все отношения нормализованы (не ниже 3НФ);
- все отношения при необходимости детализированы;
- сформированы все необходимые связи многие-ко-многим;
- указаны все необходимые ограничения;
- нарушать требования бизнес-логики недопустимо.

### 3. Схема расширений

Создайте схему `exts`, в которую установите модуль `uuid-ossp` для генерации UUID.

### 4. Типы данных

Для атрибутов типа `status` используйте:
```sql
CREATE TYPE ... AS ENUM (...)
```

### 5. Пользователь `reviewer`

Создайте пользователя со следующими параметрами:

- **Логин:** `reviewer`
- **Пароль:** `NetoSQL2026`
- **Права:**
    - полный доступ на созданную схему (например, `khashchanov_food`);
    - к `information_schema` и `pg_catalog` — только чтение;
    - доступ к схеме `exts`, если этого требует реализованная логика.

### 6. Процедура `insert_test_data(value)`

Процедура принимает целочисленное значение `value` и вносит:

- `value × 1` строк случайных данных в: `clients`, `courier`, `product_category`, `restaurant`;
- `value × 5` строк случайных данных в: `address`, `product`, `order`, `review`, `payment`;
- в таблицы со связями — необходимое количество строк;
- в таблицу `courier_pay` — по отдельной логике (см. пример в `mftiitfood.sql`).

Требования к генерации:

- генерация `id` — через `uuid-ossp`;
- символьные поля — в соответствии с размерностью `varchar` (например, `varchar(50)` → от 1 до 50 символов);
- дата и время — за последние 6 месяцев;
- статусы — через `enum_range()`;
- пустые значения (`NULL`) недопустимы.

### 7. Процедура `erase_test_data()`

Удаляет тестовые данные из **всех** отношений (все данные считаются тестовыми).

### 8. Триггер и функция `rating_change()`

Реализуйте триггер и триггерную функцию `rating_change()`, которая пересчитывает рейтинги блюд, заведений или заказов после того, как пользователь оставляет отзыв.

### 9. Функция `get_statistic()`

Возвращает таблицу со следующей структурой:

| Столбец | Описание |
| :-- | :-- |
| `restaurant_name` | Название ресторана |
| `best_product_name` | Блюдо, которое чаще всего покупают в ресторане (если несколько — одно случайное) |
| `total_amount` | Общая стоимость покупок в ресторане |
| `avg_amount` | Средняя стоимость покупок в ресторане |
| `best_user` | ФИО клиента, который чаще всего покупает в ресторане (если несколько — один случайный) |

> ⚠️ **Важно:** если названия столбцов будут отличаться от указанных — приложение работать не будет. Также будет проверяться оптимизация логики.

### 10. Процедура `add_product(...)`

Принимает аргументы согласно структуре таблицы `product` и вносит данные в таблицу `product`.

### 11. Процедура `courier_salary()`

Производит:

- подсчёт количества доставок по курьеру для расчёта процентной ставки на следующий месяц;
- получение размера оплаты по курьеру за расчётный месяц.

Новую ставку внести в соответствующую таблицу (структура уточняется), размер оплаты курьеру — в `courier_pay`.

### 12. Представление `how_much_money`

Отчёт следующего формата (с использованием рекурсии):

| Год и месяц | Сумма за месяц без комиссии | Сумма за месяц с комиссией | Сумма комиссии | Сумма комиссии за предыдущий месяц | Разница в комиссии между текущим и предыдущим месяцами | Размер оплаты курьерам | Чистая прибыль |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |

### 13. Резервная копия

- Создайте резервную копию созданной схемы в формате **бинарного архива** (`.backup`).
- Включите права доступа для учётной записи `inspector`.

## Структура базы данных

```
Table product_category {
  product_category_id uuid
  product_category_name varchar
}

Table address {
  address_id uuid
  street varchar
  house_number varchar
  apartment_office varchar
}

Table client {
  client_id uuid
  login varchar
  password varchar
  phone_number char
}

Table courier {
  courier_id uuid
  FIO varchar
  phone_number char
  status enum
  hire_date date
  dismissal_date date
}

Table client_address {
  client_id uuid
  address_id uuid
}

Table restaurant {
  restaurant_id uuid
  restaurant_name varchar
  address_id uuid
  description text
  work_hours time[]
  company_details text
  rating numeric
  status enum
}

Table product {
  product_id uuid
  product_name varchar
  product_category_id uuid
  price numeric
  restaurant_id uuid
  photo_url text
  rating numeric
  status enum
  description text
}

Table courier_pay {
  year int
  month int
  courier_id uuid
  amount numeric
}

Table order {
  order_id uuid
  courier_id uuid
  client_id uuid
  address_id uuid
  restaurant_id uuid
  order_timestamp timestamp
  delivery_timestamp timestamp
  order_amount numeric
  commission numeric
  total_amount numeric
  status enum
  pay_status enum
  description text
}

Table payment {
  payment_id uuid
  payment_transaction text
  order_id uuid
  status enum
}

Table order_structure {
  order_id uuid
  product_id uuid
  quantity numeric
}

Table review {
  review_id uuid
  client_id uuid
  review_timestamp timestamp
  entity_id uuid
  entity_type name
  order_id uuid
  description text
  photo_url text
  rating numeric
}

Ref: "address"."address_id" < "client_address"."address_id"
Ref: "client"."client_id" < "client_address"."client_id"
Ref: "address"."address_id" < "restaurant"."address_id"
Ref: "product_category"."product_category_id" < "product"."product_category_id"
Ref: "restaurant"."restaurant_id" < "product"."restaurant_id"
Ref: "courier"."courier_id" < "courier_pay"."courier_id"
Ref: "client"."client_id" < "order"."client_id"
Ref: "address"."address_id" < "order"."address_id"
Ref: "restaurant"."restaurant_id" < "order"."restaurant_id"
Ref: "courier"."courier_id" < "order"."courier_id"
Ref: "order"."order_id" < "payment"."order_id"
Ref: "order"."order_id" < "order_structure"."order_id"
Ref: "product"."product_id" < "order_structure"."product_id"
Ref: "client"."client_id" < "review"."client_id"
Ref: "order"."order_id" < "review"."order_id"
```

## Дополнительные материалы

- Пример реализации логики — файл `mftiitfood.sql`
- Исходник схемы — файл `mftiit2026.xlsx`
- Концептуальная схема — файл `Концептуальная схема МФТИ ИТ 2026.docx`

> ⚠️ **Итоговые напоминания:**
> - Весь функционал **обязательно** должен быть протестирован.
> - Тестировать необходимо под учётной записью `reviewer`.
