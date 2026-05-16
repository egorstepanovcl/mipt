-- =============================================================================
-- Stepanov Food Delivery DB
-- Schema: stepanov_food | PostgreSQL 17
-- =============================================================================

-- =============================================================================
-- Этап 1: Схемы, расширения, типы данных, пользователь reviewer
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS exts;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA exts;

CREATE SCHEMA IF NOT EXISTS stepanov_food;

-- -----------------------------------------------------------------------------
-- ENUM-типы
-- -----------------------------------------------------------------------------
CREATE TYPE stepanov_food.courier_status AS ENUM (
    'свободен',
    'занят',
    'недоступен'
);

CREATE TYPE stepanov_food.restaurant_status AS ENUM (
    'открыт',
    'закрыт',
    'временно закрыт'
);

CREATE TYPE stepanov_food.product_status AS ENUM (
    'доступен',
    'недоступен',
    'снят с продажи'
);

CREATE TYPE stepanov_food.order_status AS ENUM (
    'создан',
    'принят',
    'готовится',
    'в доставке',
    'доставлен',
    'отменён'
);

CREATE TYPE stepanov_food.pay_type AS ENUM (
    'карта',
    'наличные',
    'онлайн'
);

CREATE TYPE stepanov_food.payment_status AS ENUM (
    'ожидает',
    'выполнен',
    'отклонён'
);

-- -----------------------------------------------------------------------------
-- Пользователь reviewer
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'reviewer') THEN
        CREATE ROLE reviewer LOGIN PASSWORD 'NetoSQL2026';
    END IF;
END $$;

-- Полный доступ к рабочей схеме — схема + все текущие и будущие объекты
GRANT ALL ON SCHEMA stepanov_food TO reviewer;

ALTER DEFAULT PRIVILEGES IN SCHEMA stepanov_food
    GRANT ALL ON TABLES TO reviewer;
ALTER DEFAULT PRIVILEGES IN SCHEMA stepanov_food
    GRANT ALL ON SEQUENCES TO reviewer;
ALTER DEFAULT PRIVILEGES IN SCHEMA stepanov_food
    GRANT EXECUTE ON FUNCTIONS TO reviewer;
ALTER DEFAULT PRIVILEGES IN SCHEMA stepanov_food
    GRANT EXECUTE ON ROUTINES TO reviewer;

-- Доступ к схеме расширений для вызова exts.uuid_generate_v4()
GRANT USAGE ON SCHEMA exts TO reviewer;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA exts TO reviewer;
ALTER DEFAULT PRIVILEGES IN SCHEMA exts
    GRANT EXECUTE ON FUNCTIONS TO reviewer;

-- pg_catalog и information_schema: PUBLIC уже имеет USAGE, явный GRANT не нужен.
-- CREATE на этих схемах недоступен никому, кроме суперпользователя — без действий.

-- =============================================================================
-- Этап 2: Физическая схема — таблицы, PK, FK, constraints
-- =============================================================================

CREATE TABLE stepanov_food.product_category (
    product_category_id   uuid         PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_category_name varchar(100) NOT NULL
);

CREATE TABLE stepanov_food.address (
    address_id       uuid        PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    street           varchar(200) NOT NULL,
    house_number     varchar(20)  NOT NULL,
    apartment_office varchar(20)
);

CREATE TABLE stepanov_food.client (
    client_id    uuid         PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    login        varchar(50)  NOT NULL UNIQUE,
    password     varchar(255) NOT NULL,
    phone_number char(12)     NOT NULL
);

-- salary_rate используется в courier_salary() для расчёта процентной ставки (1–6)
CREATE TABLE stepanov_food.courier (
    courier_id     uuid                         PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    last_name      varchar(60)                  NOT NULL,
    first_name     varchar(60)                  NOT NULL,
    middle_name    varchar(60),
    phone_number   char(12)                     NOT NULL,
    status         stepanov_food.courier_status NOT NULL,
    hire_date      date                         NOT NULL,
    dismissal_date date,
    salary_rate    int                          NOT NULL DEFAULT 1
                       CHECK (salary_rate BETWEEN 1 AND 6)
);

CREATE TABLE stepanov_food.client_address (
    client_id  uuid NOT NULL REFERENCES stepanov_food.client(client_id)   ON DELETE CASCADE,
    address_id uuid NOT NULL REFERENCES stepanov_food.address(address_id) ON DELETE CASCADE,
    PRIMARY KEY (client_id, address_id)
);

CREATE TABLE stepanov_food.restaurant (
    restaurant_id   uuid                            PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    restaurant_name varchar(200)                    NOT NULL,
    address_id      uuid                            NOT NULL
                        REFERENCES stepanov_food.address(address_id) ON DELETE RESTRICT,
    description     text,
    open_time       time                            NOT NULL,
    close_time      time                            NOT NULL,
    company_details text,
    rating          numeric(3,2)                    NOT NULL DEFAULT 0
                        CHECK (rating >= 0 AND rating <= 5),
    status          stepanov_food.restaurant_status NOT NULL
);

CREATE TABLE stepanov_food.product (
    product_id          uuid                        PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_name        varchar(200)                NOT NULL,
    product_category_id uuid                        NOT NULL
                            REFERENCES stepanov_food.product_category(product_category_id) ON DELETE RESTRICT,
    price               numeric(8,2)                NOT NULL CHECK (price > 0),
    restaurant_id       uuid                        NOT NULL
                            REFERENCES stepanov_food.restaurant(restaurant_id) ON DELETE CASCADE,
    photo_url           text,
    rating              numeric(3,2)                NOT NULL DEFAULT 0
                            CHECK (rating >= 0 AND rating <= 5),
    status              stepanov_food.product_status NOT NULL,
    description         text
);

CREATE TABLE stepanov_food.courier_pay (
    courier_id uuid          NOT NULL REFERENCES stepanov_food.courier(courier_id) ON DELETE CASCADE,
    year       integer       NOT NULL,
    month      integer       NOT NULL CHECK (month BETWEEN 1 AND 12),
    amount     numeric(10,2) NOT NULL CHECK (amount >= 0),
    PRIMARY KEY (courier_id, year, month)
);

CREATE TABLE stepanov_food."order" (
    order_id           uuid                       PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    courier_id         uuid
                           REFERENCES stepanov_food.courier(courier_id)       ON DELETE RESTRICT,
    client_id          uuid                       NOT NULL
                           REFERENCES stepanov_food.client(client_id)         ON DELETE RESTRICT,
    address_id         uuid                       NOT NULL
                           REFERENCES stepanov_food.address(address_id)       ON DELETE RESTRICT,
    restaurant_id      uuid                       NOT NULL
                           REFERENCES stepanov_food.restaurant(restaurant_id) ON DELETE RESTRICT,
    order_timestamp    timestamp                  NOT NULL DEFAULT now(),
    delivery_timestamp timestamp
                           CHECK (delivery_timestamp IS NULL
                                  OR delivery_timestamp >= order_timestamp),
    order_amount       numeric(10,2)              NOT NULL CHECK (order_amount >= 1000),
    -- Бизнес-правило «комиссия фиксирована 10%» закреплено в схеме (3НФ):
    --   commission   = order_amount × 0.10
    --   total_amount = order_amount + commission
    commission         numeric(10,2)              NOT NULL
                           GENERATED ALWAYS AS (round(order_amount * 0.10, 2)) STORED,
    total_amount       numeric(10,2)              NOT NULL
                           GENERATED ALWAYS AS (order_amount + round(order_amount * 0.10, 2)) STORED,
    status             stepanov_food.order_status   NOT NULL,
    rating             numeric(3,2)                 NOT NULL DEFAULT 0
                           CHECK (rating >= 0 AND rating <= 5),
    description        text
);

CREATE TABLE stepanov_food.order_structure (
    order_id   uuid         NOT NULL REFERENCES stepanov_food."order"(order_id)   ON DELETE CASCADE,
    product_id uuid         NOT NULL REFERENCES stepanov_food.product(product_id) ON DELETE RESTRICT,
    quantity   numeric(6,2) NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (order_id, product_id)
);

-- entity_id / entity_type: полиморфная ссылка (review может быть на ресторан, блюдо или заказ)
CREATE TABLE stepanov_food.review (
    review_id        uuid         PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    client_id        uuid         NOT NULL REFERENCES stepanov_food.client(client_id) ON DELETE CASCADE,
    review_timestamp timestamp    NOT NULL DEFAULT now(),
    entity_id        uuid         NOT NULL,
    entity_type      varchar(50)  NOT NULL
                         CHECK (entity_type IN ('restaurant', 'product', 'order')),
    order_id         uuid         NOT NULL REFERENCES stepanov_food."order"(order_id) ON DELETE CASCADE,
    description      text,
    photo_url        text,
    rating           numeric(3,2) NOT NULL CHECK (rating >= 1 AND rating <= 5)
);

-- transaction_ref: ссылка на транзакцию эквайера, не PAN/CVV (бизнес-правило: данные карты не храним).
-- order_id UNIQUE: один заказ — одна оплата (1:1).
CREATE TABLE stepanov_food.payment (
    payment_id      uuid                          PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    order_id        uuid                          NOT NULL UNIQUE
                        REFERENCES stepanov_food."order"(order_id) ON DELETE CASCADE,
    transaction_ref text                          NOT NULL,
    pay_type        stepanov_food.pay_type        NOT NULL,
    status          stepanov_food.payment_status  NOT NULL DEFAULT 'ожидает',
    paid_at         timestamp
);

-- -----------------------------------------------------------------------------
-- Индексы
-- -----------------------------------------------------------------------------
CREATE INDEX ON stepanov_food.product(restaurant_id);
CREATE INDEX ON stepanov_food.product(product_category_id);
CREATE INDEX ON stepanov_food."order"(client_id);
CREATE INDEX ON stepanov_food."order"(courier_id);
CREATE INDEX ON stepanov_food."order"(restaurant_id);
CREATE INDEX ON stepanov_food."order"(order_timestamp);
CREATE INDEX ON stepanov_food.order_structure(product_id);
CREATE INDEX ON stepanov_food.review(entity_id);
CREATE INDEX ON stepanov_food.review(client_id);
CREATE INDEX ON stepanov_food.courier_pay(courier_id);

-- -----------------------------------------------------------------------------
-- Явные гранты на все таблицы схемы (дополнение к ALTER DEFAULT PRIVILEGES)
-- -----------------------------------------------------------------------------
GRANT ALL ON ALL TABLES IN SCHEMA stepanov_food TO reviewer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA stepanov_food TO reviewer;

-- =============================================================================
-- Этап 3: Функции и триггеры (add_product, rating_change)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Процедура add_product
-- Вставляет новое блюдо в таблицу product. UUID генерируется автоматически.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE stepanov_food.add_product(
    p_product_name        varchar,
    p_product_category_id uuid,
    p_price               numeric,
    p_restaurant_id       uuid,
    p_photo_url           text,
    p_rating              numeric,
    p_status              stepanov_food.product_status,
    p_description         text
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO stepanov_food.product(
        product_id,
        product_name,
        product_category_id,
        price,
        restaurant_id,
        photo_url,
        rating,
        status,
        description
    ) VALUES (
        exts.uuid_generate_v4(),
        p_product_name,
        p_product_category_id,
        p_price,
        p_restaurant_id,
        p_photo_url,
        p_rating,
        p_status,
        p_description
    );
END $$;

-- -----------------------------------------------------------------------------
-- Триггерная функция rating_change
-- После вставки / изменения / удаления отзыва пересчитывает средний рейтинг
-- сущности (ресторан или блюдо), на которую указывает review.entity_type.
-- Для DELETE использует OLD, для INSERT/UPDATE — NEW.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION stepanov_food.rating_change()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_entity_id   uuid;
    v_entity_type varchar;
    v_new_rating  numeric(3,2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_entity_id   := OLD.entity_id;
        v_entity_type := OLD.entity_type;
    ELSE
        v_entity_id   := NEW.entity_id;
        v_entity_type := NEW.entity_type;
    END IF;

    SELECT ROUND(COALESCE(AVG(rating), 0)::numeric, 2)
    INTO v_new_rating
    FROM stepanov_food.review
    WHERE entity_id = v_entity_id AND entity_type = v_entity_type;

    CASE v_entity_type
        WHEN 'restaurant' THEN
            UPDATE stepanov_food.restaurant
            SET rating = v_new_rating
            WHERE restaurant_id = v_entity_id;

        WHEN 'product' THEN
            UPDATE stepanov_food.product
            SET rating = v_new_rating
            WHERE product_id = v_entity_id;

        WHEN 'order' THEN
            UPDATE stepanov_food."order"
            SET rating = v_new_rating
            WHERE order_id = v_entity_id;

        ELSE
            NULL;
    END CASE;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_rating_change
    AFTER INSERT OR UPDATE OR DELETE ON stepanov_food.review
    FOR EACH ROW EXECUTE FUNCTION stepanov_food.rating_change();

-- =============================================================================
-- Этап 4: Генерация и очистка данных
-- =============================================================================

CREATE OR REPLACE PROCEDURE stepanov_food.erase_test_data()
LANGUAGE plpgsql AS $$
BEGIN
    TRUNCATE
        stepanov_food.review,
        stepanov_food.payment,
        stepanov_food.order_structure,
        stepanov_food.courier_pay,
        stepanov_food."order",
        stepanov_food.product,
        stepanov_food.client_address,
        stepanov_food.restaurant,
        stepanov_food.client,
        stepanov_food.courier,
        stepanov_food.product_category,
        stepanov_food.address;
END $$;

-- -----------------------------------------------------------------------------
-- insert_test_data(p_value)
-- Порядок вставки строго соблюдает FK-зависимости.
-- Строки добавляются поверх существующих (кумулятивное поведение).
-- courier_pay генерируется только для курьеров, у которых ещё нет записей.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE stepanov_food.insert_test_data(p_value int)
LANGUAGE plpgsql AS $$
DECLARE
    str           text := 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя';
    n             int;
    rec           record;
    amount        numeric(10,2);
    cur_year      int       := extract(year from current_date)::int;
    order_ts      timestamp;
BEGIN
    -- 1. address  (p_value * 5)
    FOR n IN 1..p_value * 5 LOOP
        INSERT INTO stepanov_food.address(address_id, street, house_number, apartment_office)
        VALUES (
            exts.uuid_generate_v4(),
            left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 7)::int), 200),
            (ceil(random() * 200)::int)::text,
            (ceil(random() * 999)::int)::text
        );
    END LOOP;

    -- 2. product_category  (p_value * 1)
    FOR n IN 1..p_value LOOP
        INSERT INTO stepanov_food.product_category(product_category_id, product_category_name)
        VALUES (
            exts.uuid_generate_v4(),
            left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 4)::int), 100)
        );
    END LOOP;

    -- 3. client  (p_value * 1)
    FOR n IN 1..p_value LOOP
        INSERT INTO stepanov_food.client(client_id, login, password, phone_number)
        VALUES (
            exts.uuid_generate_v4(),
            left('u' || replace(exts.uuid_generate_v4()::text, '-', ''), 50),
            left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 8)::int), 255),
            '+7' || (1000000000 + (random() * 8999999999)::bigint)::text
        );
    END LOOP;

    -- 4. courier  (p_value * 1)
    FOR n IN 1..p_value LOOP
        INSERT INTO stepanov_food.courier(
            courier_id, last_name, first_name, middle_name, phone_number, status, hire_date, salary_rate
        )
        VALUES (
            exts.uuid_generate_v4(),
            left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 2)::int), 60),
            left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 2)::int), 60),
            CASE WHEN random() > 0.3
                THEN left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 2)::int), 60)
                ELSE NULL
            END,
            '+7' || (1000000000 + (random() * 8999999999)::bigint)::text,
            (enum_range(NULL::stepanov_food.courier_status))[
                ceil(random() * cardinality(enum_range(NULL::stepanov_food.courier_status)))
            ],
            current_date - (random() * 180)::int,
            ceil(random() * 5)::int
        );
    END LOOP;

    -- 5. restaurant  (p_value * 1)
    FOR n IN 1..p_value LOOP
        INSERT INTO stepanov_food.restaurant(
            restaurant_id, restaurant_name, address_id, description,
            open_time, close_time, company_details, rating, status
        )
        VALUES (
            exts.uuid_generate_v4(),
            left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 7)::int), 200),
            (SELECT address_id FROM stepanov_food.address ORDER BY random() LIMIT 1),
            repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 10)::int),
            ((ceil(random() * 4) + 7)::text  || ':00')::time,
            ((ceil(random() * 4) + 18)::text || ':00')::time,
            repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 10)::int),
            0,
            (enum_range(NULL::stepanov_food.restaurant_status))[
                ceil(random() * cardinality(enum_range(NULL::stepanov_food.restaurant_status)))
            ]
        );
    END LOOP;

    -- 6. client_address  (p_value * 1)
    FOR rec IN
        SELECT c.client_id
        FROM stepanov_food.client c
        WHERE NOT EXISTS (
            SELECT 1 FROM stepanov_food.client_address ca WHERE ca.client_id = c.client_id
        )
        ORDER BY random()
        LIMIT p_value
    LOOP
        INSERT INTO stepanov_food.client_address(client_id, address_id)
        VALUES (
            rec.client_id,
            (SELECT address_id FROM stepanov_food.address ORDER BY random() LIMIT 1)
        );
    END LOOP;

    -- 7. product  (p_value * 5)
    FOR n IN 1..p_value * 5 LOOP
        amount := (100 + random() * 4900)::numeric(10,2);
        INSERT INTO stepanov_food.product(
            product_id, product_name, product_category_id, price,
            restaurant_id, photo_url, rating, status, description
        )
        VALUES (
            exts.uuid_generate_v4(),
            left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 7)::int), 200),
            (SELECT product_category_id FROM stepanov_food.product_category ORDER BY random() LIMIT 1),
            amount,
            (SELECT restaurant_id FROM stepanov_food.restaurant ORDER BY random() LIMIT 1),
            'https://cdn.example.com/' || exts.uuid_generate_v4()::text || '.jpg',
            0,
            (enum_range(NULL::stepanov_food.product_status))[
                ceil(random() * cardinality(enum_range(NULL::stepanov_food.product_status)))
            ],
            repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 5)::int)
        );
    END LOOP;

    -- 8. order  (p_value * 5). commission и total_amount считаются GENERATED.
    FOR n IN 1..p_value * 5 LOOP
        amount   := (1000 + random() * 4000)::numeric(10,2);
        order_ts := now() - random() * interval '6 months';
        INSERT INTO stepanov_food."order"(
            order_id, courier_id, client_id, address_id, restaurant_id,
            order_timestamp, delivery_timestamp,
            order_amount, status, description
        )
        VALUES (
            exts.uuid_generate_v4(),
            (SELECT courier_id    FROM stepanov_food.courier     ORDER BY random() LIMIT 1),
            (SELECT client_id     FROM stepanov_food.client      ORDER BY random() LIMIT 1),
            (SELECT address_id    FROM stepanov_food.address     ORDER BY random() LIMIT 1),
            (SELECT restaurant_id FROM stepanov_food.restaurant  ORDER BY random() LIMIT 1),
            order_ts,
            order_ts + (30 + (random() * 90)::int) * interval '1 minute',
            amount,
            (enum_range(NULL::stepanov_food.order_status))[
                ceil(random() * cardinality(enum_range(NULL::stepanov_food.order_status)))
            ],
            repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 5)::int)
        );
    END LOOP;

    -- 9. payment (по одной строке на каждый заказ без оплаты — 1:1).
    FOR rec IN
        SELECT o.order_id, o.order_timestamp
        FROM stepanov_food."order" o
        WHERE NOT EXISTS (
            SELECT 1 FROM stepanov_food.payment p WHERE p.order_id = o.order_id
        )
    LOOP
        INSERT INTO stepanov_food.payment(
            payment_id, order_id, transaction_ref, pay_type, status, paid_at
        ) VALUES (
            exts.uuid_generate_v4(),
            rec.order_id,
            'tx_' || replace(exts.uuid_generate_v4()::text, '-', ''),
            (enum_range(NULL::stepanov_food.pay_type))[
                ceil(random() * cardinality(enum_range(NULL::stepanov_food.pay_type)))
            ],
            (enum_range(NULL::stepanov_food.payment_status))[
                ceil(random() * cardinality(enum_range(NULL::stepanov_food.payment_status)))
            ],
            rec.order_timestamp + (random() * 60)::int * interval '1 minute'
        );
    END LOOP;

    -- 10. order_structure  (p_value * 5)
    FOR rec IN
        SELECT o.order_id
        FROM stepanov_food."order" o
        WHERE NOT EXISTS (
            SELECT 1 FROM stepanov_food.order_structure os WHERE os.order_id = o.order_id
        )
        ORDER BY random()
        LIMIT p_value * 5
    LOOP
        INSERT INTO stepanov_food.order_structure(order_id, product_id, quantity)
        VALUES (
            rec.order_id,
            (SELECT product_id FROM stepanov_food.product ORDER BY random() LIMIT 1),
            GREATEST(1, ceil(random() * 5))::numeric
        )
        ON CONFLICT DO NOTHING;
    END LOOP;

    -- 11. review  (p_value * 5)
    FOR n IN 1..p_value * 5 LOOP
        IF random() > 0.5 THEN
            INSERT INTO stepanov_food.review(
                review_id, client_id, review_timestamp,
                entity_id, entity_type, order_id,
                description, photo_url, rating
            )
            VALUES (
                exts.uuid_generate_v4(),
                (SELECT client_id FROM stepanov_food.client ORDER BY random() LIMIT 1),
                now() - random() * interval '6 months',
                (SELECT restaurant_id FROM stepanov_food.restaurant ORDER BY random() LIMIT 1),
                'restaurant',
                (SELECT order_id FROM stepanov_food."order" ORDER BY random() LIMIT 1),
                repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 5)::int),
                'https://cdn.example.com/' || exts.uuid_generate_v4()::text || '.jpg',
                GREATEST(1, ceil(random() * 5))::numeric(3,2)
            );
        ELSE
            INSERT INTO stepanov_food.review(
                review_id, client_id, review_timestamp,
                entity_id, entity_type, order_id,
                description, photo_url, rating
            )
            VALUES (
                exts.uuid_generate_v4(),
                (SELECT client_id FROM stepanov_food.client ORDER BY random() LIMIT 1),
                now() - random() * interval '6 months',
                (SELECT product_id FROM stepanov_food.product ORDER BY random() LIMIT 1),
                'product',
                (SELECT order_id FROM stepanov_food."order" ORDER BY random() LIMIT 1),
                repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 5)::int),
                'https://cdn.example.com/' || exts.uuid_generate_v4()::text || '.jpg',
                GREATEST(1, ceil(random() * 5))::numeric(3,2)
            );
        END IF;
    END LOOP;

    -- 12. courier_pay
    FOR rec IN
        SELECT c.courier_id
        FROM stepanov_food.courier c
        WHERE NOT EXISTS (
            SELECT 1 FROM stepanov_food.courier_pay cp WHERE cp.courier_id = c.courier_id
        )
    LOOP
        FOR n IN 1..12 LOOP
            INSERT INTO stepanov_food.courier_pay(courier_id, year, month, amount)
            VALUES (
                rec.courier_id,
                cur_year,
                n,
                round((random() * 500)::numeric, 2)
            );
        END LOOP;
    END LOOP;
END $$;

-- =============================================================================
-- Этап 5: Аналитика (get_statistic, courier_salary, how_much_money)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Функция get_statistic()
-- Возвращает по одной строке на каждый ресторан.
-- best_product_name — блюдо с наибольшим числом позиций в заказах;
--   при ничьей — случайное через random() в ROW_NUMBER.
-- best_user        — логин клиента с наибольшим числом заказов в ресторане;
--   при ничьей — случайный.
-- total_amount / avg_amount считаются по order_amount всех заказов ресторана.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION stepanov_food.get_statistic()
RETURNS TABLE (
    restaurant_name   varchar,
    best_product_name varchar,
    total_amount      numeric,
    avg_amount        numeric,
    best_user         varchar
)
LANGUAGE sql AS $$
WITH order_stats AS (
    SELECT
        r.restaurant_id,
        MIN(r.restaurant_name)                                AS restaurant_name,
        COALESCE(SUM(o.order_amount), 0)                      AS total_amount,
        COALESCE(ROUND(AVG(o.order_amount), 2), 0)            AS avg_amount
    FROM stepanov_food.restaurant r
    LEFT JOIN stepanov_food."order" o ON o.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_id
),
product_ranked AS (
    SELECT
        o.restaurant_id,
        p.product_id,
        MIN(p.product_name)                                   AS product_name,
        COUNT(*)                                              AS buy_count,
        ROW_NUMBER() OVER (
            PARTITION BY o.restaurant_id
            ORDER BY COUNT(*) DESC, random()
        ) AS rn
    FROM stepanov_food."order"       o
    JOIN stepanov_food.order_structure os ON os.order_id   = o.order_id
    JOIN stepanov_food.product         p  ON p.product_id  = os.product_id
    GROUP BY o.restaurant_id, p.product_id
),
best_products AS (
    SELECT restaurant_id, product_name AS best_product_name
    FROM product_ranked
    WHERE rn = 1
),
client_ranked AS (
    SELECT
        o.restaurant_id,
        o.client_id,
        MIN(c.login) AS client_login,
        COUNT(*)     AS order_count,
        ROW_NUMBER() OVER (
            PARTITION BY o.restaurant_id
            ORDER BY COUNT(*) DESC, random()
        ) AS rn
    FROM stepanov_food."order"  o
    JOIN stepanov_food.client   c ON c.client_id = o.client_id
    GROUP BY o.restaurant_id, o.client_id
),
best_clients AS (
    SELECT restaurant_id, client_login AS best_user
    FROM client_ranked
    WHERE rn = 1
)
SELECT
    os.restaurant_name,
    COALESCE(bp.best_product_name, '')::varchar AS best_product_name,
    os.total_amount,
    os.avg_amount,
    COALESCE(bc.best_user, '')::varchar          AS best_user
FROM order_stats   os
LEFT JOIN best_products bp ON bp.restaurant_id = os.restaurant_id
LEFT JOIN best_clients  bc ON bc.restaurant_id = os.restaurant_id
ORDER BY os.restaurant_name;
$$;

-- -----------------------------------------------------------------------------
-- Процедура courier_salary()
-- Запускается в последний день расчётного месяца M.
--
-- Бизнес-правило: процент по комиссии зависит от доставок за ПРОШЛЫЙ месяц
-- (M-1). Этот процент уже зашит в courier.salary_rate, выставленный в конце
-- M-1. Поэтому в одном запуске участвуют две разные выборки доставок:
--   1) M-1 — даёт процент для оплаты за M (читаем из courier.salary_rate);
--   2) M   — даёт новый salary_rate, который будет применён для оплаты M+1.
--
-- Соответствие salary_rate ↔ процент:
--   1 → 5%, 2 → 10%, 3 → 20%, 4 → 30%, 5 → 40%, 6 → 50%.
-- Соответствие доставок ↔ salary_rate:
--   0–100 → 1, 101–200 → 2, 201–300 → 3, 301–400 → 4, 401–500 → 5, 501+ → 6.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE stepanov_food.courier_salary()
LANGUAGE plpgsql AS $$
DECLARE
    billing_year       int := extract(year  from current_date)::int;
    billing_month      int := extract(month from current_date)::int;
    rec                record;
    percentage         numeric(4,2);
    courier_commission numeric(10,2);
    pay_amount         numeric(10,2);
    delivery_count     int;
BEGIN
    FOR rec IN SELECT courier_id, salary_rate FROM stepanov_food.courier LOOP

        -- 1. Оплата за расчётный месяц M: процент берём из текущего
        --    salary_rate (он был выставлен в конце M-1 по доставкам M-1).
        percentage := CASE rec.salary_rate
            WHEN 1 THEN 0.05
            WHEN 2 THEN 0.10
            WHEN 3 THEN 0.20
            WHEN 4 THEN 0.30
            WHEN 5 THEN 0.40
            ELSE        0.50
        END;

        SELECT COALESCE(SUM(commission), 0) INTO courier_commission
        FROM stepanov_food."order"
        WHERE courier_id = rec.courier_id
          AND extract(year  from order_timestamp) = billing_year
          AND extract(month from order_timestamp) = billing_month;

        pay_amount := GREATEST(0, round(courier_commission * percentage, 2));

        INSERT INTO stepanov_food.courier_pay(courier_id, year, month, amount)
        VALUES (rec.courier_id, billing_year, billing_month, pay_amount)
        ON CONFLICT (courier_id, year, month)
        DO UPDATE SET amount = EXCLUDED.amount;

        -- 2. Новый salary_rate для месяца M+1: считаем доставки за M.
        SELECT count(*) INTO delivery_count
        FROM stepanov_food."order"
        WHERE courier_id = rec.courier_id
          AND extract(year  from order_timestamp) = billing_year
          AND extract(month from order_timestamp) = billing_month;

        UPDATE stepanov_food.courier
        SET salary_rate = CASE
            WHEN delivery_count <= 100 THEN 1
            WHEN delivery_count <= 200 THEN 2
            WHEN delivery_count <= 300 THEN 3
            WHEN delivery_count <= 400 THEN 4
            WHEN delivery_count <= 500 THEN 5
            ELSE                            6
        END
        WHERE courier_id = rec.courier_id;

    END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- Представление how_much_money
-- Рекурсивный CTE генерирует последовательность месяцев от первого заказа
-- до последнего с шагом 1 месяц. К ней LEFT JOIN-ятся агрегированные данные.
-- prev_commission вычисляется оконной функцией LAG().
--
-- Колонки:
--   year_month               — период (date, первое число месяца)
--   total_without_commission — SUM(order_amount)  за месяц
--   total_with_commission    — SUM(total_amount)  за месяц (с комиссией)
--   total_commission         — SUM(commission)    за месяц
--   prev_commission          — комиссия предыдущего месяца (NULL для первого)
--   commission_diff          — разница комиссий текущего и предыдущего месяцев
--   courier_total_pay        — суммарные выплаты курьерам за месяц
--   net_profit               — чистая прибыль = комиссия − выплаты курьерам
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW stepanov_food.how_much_money AS
WITH RECURSIVE
-- 1. Рекурсия генерирует последовательность месяцев (от min до max по данным заказов)
month_series AS (
    SELECT
        MIN(date_trunc('month', order_timestamp)::date) AS period,
        MAX(date_trunc('month', order_timestamp)::date) AS max_period
    FROM stepanov_food."order"

    UNION ALL

    SELECT (period + interval '1 month')::date, max_period
    FROM month_series
    WHERE period < max_period
),
-- 2. Агрегация заказов по месяцам
monthly_orders AS (
    SELECT
        date_trunc('month', order_timestamp)::date  AS period,
        SUM(order_amount)                           AS total_without_commission,
        SUM(total_amount)                           AS total_with_commission,
        SUM(commission)                             AS total_commission
    FROM stepanov_food."order"
    GROUP BY date_trunc('month', order_timestamp)::date
),
-- 3. Агрегация выплат курьерам по месяцам
courier_monthly AS (
    SELECT
        make_date(year, month, 1)  AS period,
        SUM(amount)                AS courier_total_pay
    FROM stepanov_food.courier_pay
    GROUP BY year, month
),
-- 4. LEFT JOIN последовательности с данными
joined AS (
    SELECT
        ms.period,
        COALESCE(mo.total_without_commission, 0) AS total_without_commission,
        COALESCE(mo.total_with_commission,    0) AS total_with_commission,
        COALESCE(mo.total_commission,         0) AS total_commission,
        COALESCE(cm.courier_total_pay,        0) AS courier_total_pay
    FROM month_series ms
    LEFT JOIN monthly_orders  mo ON mo.period = ms.period
    LEFT JOIN courier_monthly cm ON cm.period = ms.period
),
-- 5. Вычисляем prev_commission через LAG
with_prev AS (
    SELECT
        period,
        total_without_commission,
        total_with_commission,
        total_commission,
        courier_total_pay,
        LAG(total_commission) OVER (ORDER BY period) AS prev_commission
    FROM joined
)
SELECT
    period                                               AS year_month,
    total_without_commission,
    total_with_commission,
    total_commission,
    prev_commission,
    total_commission - COALESCE(prev_commission, 0)      AS commission_diff,
    courier_total_pay,
    total_commission - courier_total_pay                  AS net_profit
FROM with_prev
ORDER BY period;
