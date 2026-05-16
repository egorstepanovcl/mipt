-- =============================================================================
-- test_stage_4.sql — Этап 4: insert_test_data(value), erase_test_data()
-- Запуск: ./run_tests.sh test_stage_4
-- =============================================================================

-- =============================================================================
-- 1. Процедуры существуют
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'stepanov_food' AND p.proname = 'insert_test_data'
    ) THEN
        RAISE EXCEPTION 'FAIL [4.1]: procedure insert_test_data does not exist';
    END IF;
    RAISE NOTICE 'PASS [4.1]: insert_test_data exists';
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'stepanov_food' AND p.proname = 'erase_test_data'
    ) THEN
        RAISE EXCEPTION 'FAIL [4.2]: procedure erase_test_data does not exist';
    END IF;
    RAISE NOTICE 'PASS [4.2]: erase_test_data exists';
END $$;

-- =============================================================================
-- Подготовка: гарантируем чистое состояние перед вставкой
-- =============================================================================
CALL stepanov_food.erase_test_data();

-- =============================================================================
-- 2. insert_test_data(3): проверка точных количеств строк (value = 3)
-- =============================================================================
CALL stepanov_food.insert_test_data(3);

-- value × 1
DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.client;
    IF v <> 3 THEN RAISE EXCEPTION 'FAIL [4.3]: client expected 3 rows, got %', v; END IF;
    RAISE NOTICE 'PASS [4.3]: client has % rows (expected 3)', v;
END $$;

DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.courier;
    IF v <> 3 THEN RAISE EXCEPTION 'FAIL [4.4]: courier expected 3 rows, got %', v; END IF;
    RAISE NOTICE 'PASS [4.4]: courier has % rows (expected 3)', v;
END $$;

DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.product_category;
    IF v <> 3 THEN RAISE EXCEPTION 'FAIL [4.5]: product_category expected 3 rows, got %', v; END IF;
    RAISE NOTICE 'PASS [4.5]: product_category has % rows (expected 3)', v;
END $$;

DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.restaurant;
    IF v <> 3 THEN RAISE EXCEPTION 'FAIL [4.6]: restaurant expected 3 rows, got %', v; END IF;
    RAISE NOTICE 'PASS [4.6]: restaurant has % rows (expected 3)', v;
END $$;

-- value × 5
DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.address;
    IF v <> 15 THEN RAISE EXCEPTION 'FAIL [4.7]: address expected 15 rows (3×5), got %', v; END IF;
    RAISE NOTICE 'PASS [4.7]: address has % rows (expected 15)', v;
END $$;

DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.product;
    IF v <> 15 THEN RAISE EXCEPTION 'FAIL [4.8]: product expected 15 rows (3×5), got %', v; END IF;
    RAISE NOTICE 'PASS [4.8]: product has % rows (expected 15)', v;
END $$;

DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food."order";
    IF v <> 15 THEN RAISE EXCEPTION 'FAIL [4.9]: order expected 15 rows (3×5), got %', v; END IF;
    RAISE NOTICE 'PASS [4.9]: order has % rows (expected 15)', v;
END $$;

DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.review;
    IF v <> 15 THEN RAISE EXCEPTION 'FAIL [4.10]: review expected 15 rows (3×5), got %', v; END IF;
    RAISE NOTICE 'PASS [4.10]: review has % rows (expected 15)', v;
END $$;

DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.payment;
    IF v <> 15 THEN RAISE EXCEPTION 'FAIL [4.11]: payment expected 15 rows (3×5, по одной на заказ), got %', v; END IF;
    RAISE NOTICE 'PASS [4.11]: payment has % rows (expected 15)', v;
END $$;

-- Таблицы со связями: ненулевое количество строк
DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.client_address;
    IF v < 1 THEN RAISE EXCEPTION 'FAIL [4.12]: client_address is empty after insert_test_data'; END IF;
    RAISE NOTICE 'PASS [4.12]: client_address has % rows', v;
END $$;

DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.order_structure;
    IF v < 15 THEN RAISE EXCEPTION 'FAIL [4.13]: order_structure expected >= 15 rows, got %', v; END IF;
    RAISE NOTICE 'PASS [4.13]: order_structure has % rows', v;
END $$;

-- courier_pay: по формуле num_couriers × 12
DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.courier_pay;
    IF v <> 36 THEN RAISE EXCEPTION 'FAIL [4.14]: courier_pay expected 36 rows (3 couriers × 12 months), got %', v; END IF;
    RAISE NOTICE 'PASS [4.14]: courier_pay has % rows (expected 36)', v;
END $$;

-- =============================================================================
-- 3. Проверка отсутствия NULL в NOT NULL столбцах после вставки
-- =============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM stepanov_food.client WHERE login IS NULL OR password IS NULL OR phone_number IS NULL) THEN
        RAISE EXCEPTION 'FAIL [4.15]: NULL found in client NOT NULL columns';
    END IF;
    RAISE NOTICE 'PASS [4.15]: no NULLs in client';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM stepanov_food.courier WHERE last_name IS NULL OR first_name IS NULL OR phone_number IS NULL OR status IS NULL OR hire_date IS NULL) THEN
        RAISE EXCEPTION 'FAIL [4.16]: NULL found in courier NOT NULL columns';
    END IF;
    RAISE NOTICE 'PASS [4.16]: no NULLs in courier';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM stepanov_food.restaurant WHERE restaurant_name IS NULL OR address_id IS NULL OR open_time IS NULL OR close_time IS NULL OR rating IS NULL OR status IS NULL) THEN
        RAISE EXCEPTION 'FAIL [4.17]: NULL found in restaurant NOT NULL columns';
    END IF;
    RAISE NOTICE 'PASS [4.17]: no NULLs in restaurant';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM stepanov_food.product WHERE product_name IS NULL OR product_category_id IS NULL OR price IS NULL OR restaurant_id IS NULL OR rating IS NULL OR status IS NULL) THEN
        RAISE EXCEPTION 'FAIL [4.18]: NULL found in product NOT NULL columns';
    END IF;
    RAISE NOTICE 'PASS [4.18]: no NULLs in product';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM stepanov_food."order" WHERE client_id IS NULL OR address_id IS NULL OR restaurant_id IS NULL OR order_timestamp IS NULL OR order_amount IS NULL OR commission IS NULL OR total_amount IS NULL OR status IS NULL) THEN
        RAISE EXCEPTION 'FAIL [4.19]: NULL found in order NOT NULL columns';
    END IF;
    RAISE NOTICE 'PASS [4.19]: no NULLs in order';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM stepanov_food.review WHERE client_id IS NULL OR review_timestamp IS NULL OR entity_id IS NULL OR entity_type IS NULL OR order_id IS NULL OR rating IS NULL) THEN
        RAISE EXCEPTION 'FAIL [4.20]: NULL found in review NOT NULL columns';
    END IF;
    RAISE NOTICE 'PASS [4.20]: no NULLs in review';
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM stepanov_food.payment WHERE order_id IS NULL OR transaction_ref IS NULL OR pay_type IS NULL OR status IS NULL) THEN
        RAISE EXCEPTION 'FAIL [4.20b]: NULL found in payment NOT NULL columns';
    END IF;
    RAISE NOTICE 'PASS [4.20b]: no NULLs in payment';
END $$;

-- 1:1 связь payment ↔ order должна быть строгой: каждому заказу — один платёж.
DO $$
DECLARE orphans int; dups int;
BEGIN
    SELECT count(*) INTO orphans
    FROM stepanov_food."order" o
    LEFT JOIN stepanov_food.payment p ON p.order_id = o.order_id
    WHERE p.payment_id IS NULL;

    IF orphans > 0 THEN
        RAISE EXCEPTION 'FAIL [4.20c]: % orders without payment row', orphans;
    END IF;

    SELECT count(*) INTO dups
    FROM (
        SELECT order_id FROM stepanov_food.payment
        GROUP BY order_id HAVING count(*) > 1
    ) x;
    IF dups > 0 THEN
        RAISE EXCEPTION 'FAIL [4.20c]: % orders have more than one payment row', dups;
    END IF;
    RAISE NOTICE 'PASS [4.20c]: each order has exactly one payment';
END $$;

-- =============================================================================
-- 4. Временные метки — не старше 6 месяцев
-- =============================================================================
DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v
    FROM stepanov_food."order"
    WHERE order_timestamp < now() - interval '6 months';
    IF v > 0 THEN
        RAISE EXCEPTION 'FAIL [4.21]: % orders have order_timestamp older than 6 months', v;
    END IF;
    RAISE NOTICE 'PASS [4.21]: all order_timestamp values are within last 6 months';
END $$;

DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v
    FROM stepanov_food.review
    WHERE review_timestamp < now() - interval '6 months';
    IF v > 0 THEN
        RAISE EXCEPTION 'FAIL [4.22]: % reviews have review_timestamp older than 6 months', v;
    END IF;
    RAISE NOTICE 'PASS [4.22]: all review_timestamp values are within last 6 months';
END $$;

-- =============================================================================
-- 5. insert_test_data кумулятивна: второй вызов добавляет строки поверх
-- =============================================================================
CALL stepanov_food.insert_test_data(2);

DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.client;
    IF v <> 5 THEN RAISE EXCEPTION 'FAIL [4.23]: after insert(3)+insert(2) client expected 5, got %', v; END IF;
    RAISE NOTICE 'PASS [4.23]: insert_test_data is cumulative: client has % rows', v;
END $$;

-- =============================================================================
-- 6. erase_test_data() — все таблицы пусты после очистки
-- =============================================================================
CALL stepanov_food.erase_test_data();

DO $$
DECLARE
    tables text[] := ARRAY[
        'product_category', 'address', 'client', 'courier', 'client_address',
        'restaurant', 'product', 'courier_pay', 'order',
        'order_structure', 'review', 'payment'
    ];
    t   text;
    cnt bigint;
BEGIN
    FOREACH t IN ARRAY tables LOOP
        EXECUTE format('SELECT count(*) FROM stepanov_food.%I', t) INTO cnt;
        IF cnt <> 0 THEN
            RAISE EXCEPTION 'FAIL [4.24]: table stepanov_food.% is not empty after erase_test_data (% rows)', t, cnt;
        END IF;
        RAISE NOTICE 'PASS [4.24]: stepanov_food.% is empty after erase_test_data', t;
    END LOOP;
END $$;

-- =============================================================================
DO $$ BEGIN RAISE NOTICE '=== ALL STAGE 4 TESTS PASSED ==='; END $$;
