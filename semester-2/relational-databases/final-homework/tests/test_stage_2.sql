-- =============================================================================
-- test_stage_2.sql — Этап 2: физическая схема (таблицы, типы, PK, FK, constraints)
-- Запуск: ./run_tests.sh test_stage_2
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Вспомогательная функция: assert_column
-- Проверяет существование колонки, её тип и nullable-флаг.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION stepanov_food._assert_column(
    p_table      text,
    p_column     text,
    p_data_type  text,        -- значение из information_schema.columns.data_type
    p_udt_name   text,        -- значение из information_schema.columns.udt_name (для enum/кастомных типов)
    p_nullable   boolean      -- true = NULL разрешён, false = NOT NULL
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    r record;
BEGIN
    SELECT data_type, udt_name, is_nullable
    INTO r
    FROM information_schema.columns
    WHERE table_schema = 'stepanov_food'
      AND table_name   = p_table
      AND column_name  = p_column;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'FAIL: column stepanov_food.%.% does not exist', p_table, p_column;
    END IF;

    IF r.data_type <> p_data_type THEN
        RAISE EXCEPTION 'FAIL: stepanov_food.%.% — expected data_type=%, got %',
            p_table, p_column, p_data_type, r.data_type;
    END IF;

    IF p_udt_name IS NOT NULL AND r.udt_name <> p_udt_name THEN
        RAISE EXCEPTION 'FAIL: stepanov_food.%.% — expected udt_name=%, got %',
            p_table, p_column, p_udt_name, r.udt_name;
    END IF;

    IF p_nullable = false AND r.is_nullable <> 'NO' THEN
        RAISE EXCEPTION 'FAIL: stepanov_food.%.% must be NOT NULL', p_table, p_column;
    END IF;

    RAISE NOTICE 'PASS: stepanov_food.%.% [% / %] nullable=%', p_table, p_column, p_data_type, r.udt_name, p_nullable;
END $$;

-- ---------------------------------------------------------------------------
-- Вспомогательная функция: assert_pk
-- Проверяет наличие PRIMARY KEY на указанных столбцах.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION stepanov_food._assert_pk(
    p_table   text,
    p_columns text[]
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    actual_cols text[];
BEGIN
    SELECT array_agg(a.attname ORDER BY array_position(i.indkey, a.attnum))
    INTO actual_cols
    FROM pg_index i
    JOIN pg_class c  ON c.oid  = i.indrelid
    JOIN pg_class ci ON ci.oid = i.indexrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(i.indkey)
    WHERE n.nspname    = 'stepanov_food'
      AND c.relname    = p_table
      AND i.indisprimary = true;

    IF actual_cols IS NULL THEN
        RAISE EXCEPTION 'FAIL: table stepanov_food.% has no PRIMARY KEY', p_table;
    END IF;

    IF actual_cols <> p_columns THEN
        RAISE EXCEPTION 'FAIL: stepanov_food.% PK columns expected=%, got=%',
            p_table, p_columns, actual_cols;
    END IF;

    RAISE NOTICE 'PASS: stepanov_food.% PK=%', p_table, p_columns;
END $$;

-- ---------------------------------------------------------------------------
-- Вспомогательная функция: assert_fk
-- Проверяет наличие FK с нужной ссылкой.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION stepanov_food._assert_fk(
    p_table      text,
    p_column     text,
    p_ref_table  text,
    p_ref_column text
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.referential_constraints rc
        JOIN information_schema.key_column_usage kcu
            ON kcu.constraint_name = rc.constraint_name
           AND kcu.constraint_schema = rc.constraint_schema
        JOIN information_schema.key_column_usage kcu2
            ON kcu2.constraint_name  = rc.unique_constraint_name
           AND kcu2.constraint_schema = rc.unique_constraint_schema
        WHERE kcu.table_schema  = 'stepanov_food'
          AND kcu.table_name    = p_table
          AND kcu.column_name   = p_column
          AND kcu2.table_name   = p_ref_table
          AND kcu2.column_name  = p_ref_column
    ) THEN
        RAISE EXCEPTION 'FAIL: FK stepanov_food.%.% -> stepanov_food.%.% does not exist',
            p_table, p_column, p_ref_table, p_ref_column;
    END IF;
    RAISE NOTICE 'PASS: FK stepanov_food.%.% -> stepanov_food.%.%',
        p_table, p_column, p_ref_table, p_ref_column;
END $$;

-- =============================================================================
-- 1. Все таблицы существуют
-- =============================================================================
DO $$
DECLARE
    tables text[] := ARRAY[
        'product_category', 'address', 'client', 'courier', 'client_address',
        'restaurant', 'product', 'courier_pay', 'order',
        'order_structure', 'review'
    ];
    t text;
BEGIN
    FOREACH t IN ARRAY tables LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'stepanov_food' AND table_name = t
        ) THEN
            RAISE EXCEPTION 'FAIL [2.1]: table stepanov_food.% does not exist', t;
        END IF;
        RAISE NOTICE 'PASS [2.1]: table stepanov_food.% exists', t;
    END LOOP;
END $$;

-- =============================================================================
-- 2. product_category — колонки, типы, PK
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('product_category', 'product_category_id',   'uuid',               'uuid',    false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('product_category', 'product_category_name', 'character varying',  NULL,      false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('product_category', ARRAY['product_category_id']); END $$;

-- =============================================================================
-- 3. address — колонки, типы, PK
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('address', 'address_id',        'uuid',              'uuid', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('address', 'street',            'character varying', NULL,   false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('address', 'house_number',      'character varying', NULL,   false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('address', 'apartment_office',  'character varying', NULL,   true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('address', ARRAY['address_id']); END $$;

-- =============================================================================
-- 4. client — колонки, типы, PK
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('client', 'client_id',    'uuid',              'uuid', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('client', 'login',        'character varying', NULL,   false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('client', 'password',     'character varying', NULL,   false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('client', 'phone_number', 'character',         NULL,   false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('client', ARRAY['client_id']); END $$;

-- =============================================================================
-- 5. courier — колонки, типы, ENUM, PK
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier', 'courier_id',      'uuid',              'uuid',            false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier', 'last_name',       'character varying', NULL,              false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier', 'first_name',      'character varying', NULL,              false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier', 'middle_name',     'character varying', NULL,              true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier', 'phone_number',    'character',         NULL,              false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier', 'status',          'USER-DEFINED',      'courier_status',  false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier', 'hire_date',       'date',              'date',            false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier', 'dismissal_date',  'date',              'date',            true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('courier', ARRAY['courier_id']); END $$;

-- =============================================================================
-- 6. client_address — составной PK, FK → client, FK → address
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('client_address', 'client_id',  'uuid', 'uuid', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('client_address', 'address_id', 'uuid', 'uuid', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('client_address', ARRAY['client_id', 'address_id']); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('client_address', 'client_id',  'client',  'client_id');  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('client_address', 'address_id', 'address', 'address_id'); END $$;

-- =============================================================================
-- 7. restaurant — колонки, типы, ENUM, PK, FK → address
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('restaurant', 'restaurant_id',   'uuid',              'uuid',              false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('restaurant', 'restaurant_name', 'character varying', NULL,                false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('restaurant', 'address_id',      'uuid',              'uuid',              false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('restaurant', 'description',     'text',              'text',              true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('restaurant', 'open_time',       'time without time zone', 'time',          false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('restaurant', 'close_time',      'time without time zone', 'time',          false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('restaurant', 'company_details', 'text',              'text',              true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('restaurant', 'rating',          'numeric',           'numeric',           false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('restaurant', 'status',          'USER-DEFINED',      'restaurant_status', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('restaurant', ARRAY['restaurant_id']); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('restaurant', 'address_id', 'address', 'address_id'); END $$;

-- =============================================================================
-- 8. product — колонки, типы, ENUM, PK, FK → product_category, FK → restaurant
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('product', 'product_id',          'uuid',              'uuid',           false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('product', 'product_name',        'character varying', NULL,             false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('product', 'product_category_id', 'uuid',              'uuid',           false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('product', 'price',               'numeric',           'numeric',        false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('product', 'restaurant_id',       'uuid',              'uuid',           false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('product', 'photo_url',           'text',              'text',           true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('product', 'rating',              'numeric',           'numeric',        false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('product', 'status',              'USER-DEFINED',      'product_status', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('product', 'description',         'text',              'text',           true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('product', ARRAY['product_id']); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('product', 'product_category_id', 'product_category', 'product_category_id'); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('product', 'restaurant_id',       'restaurant',       'restaurant_id');       END $$;

-- =============================================================================
-- 9. courier_pay — составной PK, FK → courier
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier_pay', 'courier_id', 'uuid',    'uuid',    false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier_pay', 'year',       'integer', 'int4',    false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier_pay', 'month',      'integer', 'int4',    false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('courier_pay', 'amount',     'numeric', 'numeric', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('courier_pay', ARRAY['courier_id', 'year', 'month']); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('courier_pay', 'courier_id', 'courier', 'courier_id'); END $$;

-- CHECK: month BETWEEN 1 AND 12
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class cl ON cl.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = cl.relnamespace
        WHERE n.nspname = 'stepanov_food'
          AND cl.relname = 'courier_pay'
          AND c.contype = 'c'
          AND pg_get_constraintdef(c.oid) LIKE '%month%'
    ) THEN
        RAISE EXCEPTION 'FAIL [2.9]: courier_pay missing CHECK constraint on month';
    END IF;
    RAISE NOTICE 'PASS [2.9]: courier_pay has CHECK on month';
END $$;

-- =============================================================================
-- 10. order — колонки, типы, ENUM, PK, FK
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'order_id',           'uuid',              'uuid',         false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'courier_id',         'uuid',              'uuid',         true); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'client_id',          'uuid',              'uuid',         false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'address_id',         'uuid',              'uuid',         false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'restaurant_id',      'uuid',              'uuid',         false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'order_timestamp',    'timestamp without time zone', 'timestamp', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'delivery_timestamp', 'timestamp without time zone', 'timestamp', true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'order_amount',       'numeric',           'numeric',      false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'commission',         'numeric',           'numeric',      false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'total_amount',       'numeric',           'numeric',      false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'status',             'USER-DEFINED',      'order_status',    false); END $$;
-- pay_status / pay_type вынесены в отдельную таблицу payment (см. секцию 16).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='stepanov_food' AND table_name='order'
                 AND column_name IN ('pay_status','pay_type')) THEN
        RAISE EXCEPTION 'FAIL [2.10b]: order should not have pay_status/pay_type — they belong to payment';
    END IF;
    RAISE NOTICE 'PASS [2.10b]: order has no pay_status/pay_type (moved to payment)';
END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'rating',             'numeric',           'numeric',         false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order', 'description',        'text',              'text',            true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('order', ARRAY['order_id']); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('order', 'courier_id',    'courier',    'courier_id');    END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('order', 'client_id',     'client',     'client_id');     END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('order', 'address_id',    'address',    'address_id');    END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('order', 'restaurant_id', 'restaurant', 'restaurant_id'); END $$;

-- commission и total_amount транзитивно зависят от order_amount (3НФ),
-- бизнес-правило «комиссия фиксирована 10%» закрепляем через GENERATED ALWAYS.
DO $$
DECLARE
    bad text;
BEGIN
    SELECT string_agg(attname, ', ') INTO bad
    FROM pg_attribute a
    JOIN pg_class    c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'stepanov_food'
      AND c.relname = 'order'
      AND a.attname IN ('commission', 'total_amount')
      AND a.attgenerated <> 's';

    IF bad IS NOT NULL THEN
        RAISE EXCEPTION 'FAIL [2.10c]: order.{%} must be GENERATED ALWAYS AS (...) STORED', bad;
    END IF;
    RAISE NOTICE 'PASS [2.10c]: order.commission and order.total_amount are GENERATED ALWAYS STORED';
END $$;

-- Бизнес-правило «заказ день в день» как минимум: delivery_timestamp >= order_timestamp.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class cl ON cl.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = cl.relnamespace
        WHERE n.nspname = 'stepanov_food'
          AND cl.relname = 'order'
          AND c.contype  = 'c'
          AND pg_get_constraintdef(c.oid) LIKE '%delivery_timestamp%'
          AND pg_get_constraintdef(c.oid) LIKE '%order_timestamp%'
    ) THEN
        RAISE EXCEPTION 'FAIL [2.10d]: order missing CHECK linking delivery_timestamp to order_timestamp';
    END IF;
    RAISE NOTICE 'PASS [2.10d]: order has CHECK on delivery_timestamp vs order_timestamp';
END $$;

-- =============================================================================
-- 11. order_structure — составной PK, FK → order, FK → product
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('order_structure', 'order_id',   'uuid',    'uuid',    false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order_structure', 'product_id', 'uuid',    'uuid',    false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('order_structure', 'quantity',   'numeric', 'numeric', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('order_structure', ARRAY['order_id', 'product_id']); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('order_structure', 'order_id',   'order',   'order_id');   END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('order_structure', 'product_id', 'product', 'product_id'); END $$;

-- CHECK: quantity > 0
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class cl ON cl.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = cl.relnamespace
        WHERE n.nspname = 'stepanov_food'
          AND cl.relname = 'order_structure'
          AND c.contype = 'c'
          AND pg_get_constraintdef(c.oid) LIKE '%quantity%'
    ) THEN
        RAISE EXCEPTION 'FAIL [2.12]: order_structure missing CHECK constraint on quantity';
    END IF;
    RAISE NOTICE 'PASS [2.12]: order_structure has CHECK on quantity';
END $$;

-- =============================================================================
-- 13. review — колонки, типы, PK, FK → client, FK → order
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('review', 'review_id',         'uuid',              'uuid',      false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('review', 'client_id',         'uuid',              'uuid',      false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('review', 'review_timestamp',  'timestamp without time zone', 'timestamp', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('review', 'entity_id',         'uuid',              'uuid',      false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('review', 'entity_type',       'character varying', NULL,        false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('review', 'order_id',          'uuid',              'uuid',      false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('review', 'description',       'text',              'text',      true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('review', 'photo_url',         'text',              'text',      true);  END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('review', 'rating',            'numeric',           'numeric',   false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('review', ARRAY['review_id']); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('review', 'client_id', 'client', 'client_id'); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('review', 'order_id',  'order',  'order_id');  END $$;

-- CHECK: rating BETWEEN 1 AND 5
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class cl ON cl.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = cl.relnamespace
        WHERE n.nspname = 'stepanov_food'
          AND cl.relname = 'review'
          AND c.contype = 'c'
          AND pg_get_constraintdef(c.oid) LIKE '%rating%'
    ) THEN
        RAISE EXCEPTION 'FAIL [2.13]: review missing CHECK constraint on rating';
    END IF;
    RAISE NOTICE 'PASS [2.13]: review has CHECK on rating';
END $$;

-- CHECK: entity_type ограничен значениями, которые умеет обрабатывать триггер.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class cl ON cl.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = cl.relnamespace
        WHERE n.nspname = 'stepanov_food'
          AND cl.relname = 'review'
          AND c.contype = 'c'
          AND pg_get_constraintdef(c.oid) LIKE '%entity_type%'
          AND pg_get_constraintdef(c.oid) LIKE '%restaurant%'
          AND pg_get_constraintdef(c.oid) LIKE '%product%'
          AND pg_get_constraintdef(c.oid) LIKE '%order%'
    ) THEN
        RAISE EXCEPTION 'FAIL [2.13b]: review missing CHECK constraint restricting entity_type to restaurant/product/order';
    END IF;
    RAISE NOTICE 'PASS [2.13b]: review has CHECK on entity_type';
END $$;

-- =============================================================================
-- 14. CHECK constraint: product.price > 0
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class cl ON cl.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = cl.relnamespace
        WHERE n.nspname = 'stepanov_food'
          AND cl.relname = 'product'
          AND c.contype = 'c'
          AND pg_get_constraintdef(c.oid) LIKE '%price%'
    ) THEN
        RAISE EXCEPTION 'FAIL [2.14]: product missing CHECK constraint on price';
    END IF;
    RAISE NOTICE 'PASS [2.14]: product has CHECK on price';
END $$;

-- Функциональная проверка GENERATED-колонок:
-- INSERT order_amount=2000 (без указания commission/total_amount) → 200, 2200.
DO $$
DECLARE
    v_addr_id  uuid := exts.uuid_generate_v4();
    v_cli_id   uuid := exts.uuid_generate_v4();
    v_rest_id  uuid := exts.uuid_generate_v4();
    v_order_id uuid := exts.uuid_generate_v4();
    v_comm     numeric;
    v_total    numeric;
BEGIN
    INSERT INTO stepanov_food.address(address_id, street, house_number)
        VALUES (v_addr_id, 'Test', '1');
    INSERT INTO stepanov_food.client(client_id, login, password, phone_number)
        VALUES (v_cli_id, 'gen_login', 'p', '+70000000099');
    INSERT INTO stepanov_food.restaurant(
        restaurant_id, restaurant_name, address_id, open_time, close_time, status
    ) VALUES (v_rest_id, 'T', v_addr_id, '08:00', '22:00', 'открыт');

    INSERT INTO stepanov_food."order"(
        order_id, client_id, address_id, restaurant_id,
        order_amount, status
    ) VALUES (
        v_order_id, v_cli_id, v_addr_id, v_rest_id, 2000, 'создан'
    );

    SELECT commission, total_amount INTO v_comm, v_total
    FROM stepanov_food."order" WHERE order_id = v_order_id;

    IF v_comm <> 200.00 OR v_total <> 2200.00 THEN
        RAISE EXCEPTION 'FAIL [2.14b]: GENERATED columns wrong: commission=%, total_amount=% (expected 200.00, 2200.00)',
            v_comm, v_total;
    END IF;
    RAISE NOTICE 'PASS [2.14b]: order_amount=2000 → commission=200, total_amount=2200 (GENERATED)';

    -- Чистим за собой, чтобы не повлиять на последующие тесты.
    DELETE FROM stepanov_food."order"      WHERE order_id      = v_order_id;
    DELETE FROM stepanov_food.restaurant   WHERE restaurant_id = v_rest_id;
    DELETE FROM stepanov_food.client       WHERE client_id     = v_cli_id;
    DELETE FROM stepanov_food.address      WHERE address_id    = v_addr_id;
END $$;

-- =============================================================================
-- 16. payment — отдельная сущность, ссылается на order 1:1.
--     Хранит статус оплаты и тип, плюс ссылку на транзакцию эквайера.
--     Данные карты не хранятся (бизнес-правило).
-- =============================================================================
DO $$ BEGIN PERFORM stepanov_food._assert_column('payment', 'payment_id',       'uuid',              'uuid',           false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('payment', 'order_id',         'uuid',              'uuid',           false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('payment', 'transaction_ref',  'text',              'text',           false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('payment', 'pay_type',         'USER-DEFINED',      'pay_type',       false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('payment', 'status',           'USER-DEFINED',      'payment_status', false); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_column('payment', 'paid_at',          'timestamp without time zone', 'timestamp', true); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_pk('payment', ARRAY['payment_id']); END $$;
DO $$ BEGIN PERFORM stepanov_food._assert_fk('payment', 'order_id', 'order', 'order_id'); END $$;

-- order_id должен быть UNIQUE: один заказ — одна оплата (1:1).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class cl     ON cl.oid = c.conrelid
        JOIN pg_namespace n  ON n.oid  = cl.relnamespace
        JOIN pg_attribute a  ON a.attrelid = cl.oid AND a.attnum = ANY(c.conkey)
        WHERE n.nspname = 'stepanov_food'
          AND cl.relname = 'payment'
          AND c.contype IN ('u', 'p')
          AND a.attname = 'order_id'
          AND cardinality(c.conkey) = 1
    ) THEN
        RAISE EXCEPTION 'FAIL [2.16]: payment.order_id must be UNIQUE (one payment per order)';
    END IF;
    RAISE NOTICE 'PASS [2.16]: payment.order_id is UNIQUE';
END $$;

-- =============================================================================
-- 15. reviewer имеет SELECT на все таблицы схемы
-- =============================================================================
DO $$
DECLARE
    tables text[] := ARRAY[
        'product_category', 'address', 'client', 'courier', 'client_address',
        'restaurant', 'product', 'courier_pay', 'order',
        'order_structure', 'review', 'payment'
    ];
    t text;
BEGIN
    FOREACH t IN ARRAY tables LOOP
        IF NOT has_table_privilege('reviewer', 'stepanov_food.' || quote_ident(t), 'SELECT') THEN
            RAISE EXCEPTION 'FAIL [2.15]: reviewer has no SELECT on stepanov_food.%', t;
        END IF;
        RAISE NOTICE 'PASS [2.15]: reviewer has SELECT on stepanov_food.%', t;
    END LOOP;
END $$;

-- =============================================================================
-- Очистка вспомогательных функций
-- =============================================================================
DROP FUNCTION stepanov_food._assert_column(text, text, text, text, boolean);
DROP FUNCTION stepanov_food._assert_pk(text, text[]);
DROP FUNCTION stepanov_food._assert_fk(text, text, text, text);

-- =============================================================================
DO $$ BEGIN RAISE NOTICE '=== ALL STAGE 2 TESTS PASSED ==='; END $$;
