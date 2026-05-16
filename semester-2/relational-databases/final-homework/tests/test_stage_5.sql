-- =============================================================================
-- test_stage_5.sql — Этап 5: get_statistic(), courier_salary(), how_much_money
-- Запуск: ./run_tests.sh test_stage_5
-- =============================================================================

-- =============================================================================
-- 1. Объекты существуют
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'stepanov_food' AND p.proname = 'get_statistic'
    ) THEN
        RAISE EXCEPTION 'FAIL [5.1]: function stepanov_food.get_statistic() does not exist';
    END IF;
    RAISE NOTICE 'PASS [5.1]: get_statistic exists';
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'stepanov_food' AND p.proname = 'courier_salary'
    ) THEN
        RAISE EXCEPTION 'FAIL [5.2]: procedure stepanov_food.courier_salary() does not exist';
    END IF;
    RAISE NOTICE 'PASS [5.2]: courier_salary exists';
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'stepanov_food'
          AND c.relname = 'how_much_money'
          AND c.relkind = 'v'
    ) THEN
        RAISE EXCEPTION 'FAIL [5.3]: view stepanov_food.how_much_money does not exist';
    END IF;
    RAISE NOTICE 'PASS [5.3]: view how_much_money exists';
END $$;

-- =============================================================================
-- Подготовка: загружаем тестовые данные
-- =============================================================================
CALL stepanov_food.erase_test_data();
CALL stepanov_food.insert_test_data(5);

-- =============================================================================
-- 2. get_statistic() — имена столбцов (строгое posymvol'noe совпадение)
-- =============================================================================
DO $$
DECLARE
    required_cols text[] := ARRAY[
        'restaurant_name', 'best_product_name',
        'total_amount', 'avg_amount', 'best_user'
    ];
    col text;
BEGIN
    -- Создаём временную таблицу из результата функции (без строк)
    CREATE TEMP TABLE _gs_shape AS
        SELECT * FROM stepanov_food.get_statistic() LIMIT 0;

    FOREACH col IN ARRAY required_cols LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = '_gs_shape' AND column_name = col
        ) THEN
            RAISE EXCEPTION 'FAIL [5.4]: get_statistic() missing column "%"', col;
        END IF;
        RAISE NOTICE 'PASS [5.4]: get_statistic() has column "%"', col;
    END LOOP;

    DROP TABLE _gs_shape;
END $$;

-- =============================================================================
-- 3. get_statistic() — возвращает строки (по одной на ресторан)
-- =============================================================================
DO $$
DECLARE
    row_count  int;
    rest_count int;
BEGIN
    SELECT count(*) INTO row_count  FROM stepanov_food.get_statistic();
    SELECT count(*) INTO rest_count FROM stepanov_food.restaurant;

    IF row_count <> rest_count THEN
        RAISE EXCEPTION 'FAIL [5.5]: get_statistic() returned % rows, expected % (one per restaurant)',
            row_count, rest_count;
    END IF;
    RAISE NOTICE 'PASS [5.5]: get_statistic() returned % rows (one per restaurant)', row_count;
END $$;

-- =============================================================================
-- 4. get_statistic() — типы данных и отсутствие NULL в ключевых столбцах
-- =============================================================================
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN SELECT * FROM stepanov_food.get_statistic() LOOP
        IF r.restaurant_name IS NULL THEN
            RAISE EXCEPTION 'FAIL [5.6]: get_statistic() returned NULL restaurant_name';
        END IF;
        IF r.total_amount IS NULL OR r.total_amount < 0 THEN
            RAISE EXCEPTION 'FAIL [5.6]: get_statistic() total_amount is NULL or negative for %',
                r.restaurant_name;
        END IF;
        IF r.avg_amount IS NULL OR r.avg_amount < 0 THEN
            RAISE EXCEPTION 'FAIL [5.6]: get_statistic() avg_amount is NULL or negative for %',
                r.restaurant_name;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS [5.6]: get_statistic() has no NULLs in required columns, all amounts >= 0';
END $$;

-- =============================================================================
-- 5. get_statistic() — avg_amount <= total_amount для каждого ресторана
-- =============================================================================
DO $$
DECLARE r record;
BEGIN
    FOR r IN SELECT * FROM stepanov_food.get_statistic() LOOP
        IF r.avg_amount > r.total_amount THEN
            RAISE EXCEPTION 'FAIL [5.7]: avg_amount (%) > total_amount (%) for restaurant %',
                r.avg_amount, r.total_amount, r.restaurant_name;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS [5.7]: avg_amount <= total_amount for all restaurants';
END $$;

-- =============================================================================
-- 6. how_much_money — имена столбцов
-- =============================================================================
DO $$
DECLARE
    required_cols text[] := ARRAY[
        'year_month', 'total_without_commission', 'total_with_commission',
        'total_commission', 'prev_commission', 'commission_diff',
        'courier_total_pay', 'net_profit'
    ];
    col text;
BEGIN
    FOREACH col IN ARRAY required_cols LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'stepanov_food'
              AND table_name   = 'how_much_money'
              AND column_name  = col
        ) THEN
            RAISE EXCEPTION 'FAIL [5.8]: view how_much_money missing column "%"', col;
        END IF;
        RAISE NOTICE 'PASS [5.8]: how_much_money has column "%"', col;
    END LOOP;
END $$;

-- =============================================================================
-- 7. how_much_money — возвращает строки и суммы неотрицательны
-- =============================================================================
DO $$
DECLARE
    row_count int;
    r         record;
BEGIN
    SELECT count(*) INTO row_count FROM stepanov_food.how_much_money;
    IF row_count < 1 THEN
        RAISE EXCEPTION 'FAIL [5.9]: how_much_money returned 0 rows';
    END IF;
    RAISE NOTICE 'PASS [5.9]: how_much_money returned % rows', row_count;

    FOR r IN SELECT * FROM stepanov_food.how_much_money LOOP
        IF r.total_without_commission < 0 THEN
            RAISE EXCEPTION 'FAIL [5.9]: how_much_money total_without_commission < 0 in row %', r.year_month;
        END IF;
        IF r.total_commission < 0 THEN
            RAISE EXCEPTION 'FAIL [5.9]: how_much_money total_commission < 0 in row %', r.year_month;
        END IF;
    END LOOP;
    RAISE NOTICE 'PASS [5.9]: how_much_money all amounts are non-negative';
END $$;

-- =============================================================================
-- 8. how_much_money — рекурсия: prev_commission для первой строки IS NULL
--    (нет предыдущего месяца), для последующих — ненулевое значение
-- =============================================================================
DO $$
DECLARE
    first_prev  numeric;
    second_prev numeric;
    total_rows  int;
BEGIN
    SELECT count(*) INTO total_rows FROM stepanov_food.how_much_money;

    SELECT prev_commission INTO first_prev
    FROM stepanov_food.how_much_money
    ORDER BY year_month
    LIMIT 1;

    IF first_prev IS NOT NULL AND first_prev <> 0 THEN
        RAISE EXCEPTION 'FAIL [5.10]: first row prev_commission should be NULL or 0 (no previous month), got %',
            first_prev;
    END IF;
    RAISE NOTICE 'PASS [5.10]: first row prev_commission = % (correct: no prior month)', first_prev;

    -- Если больше одной строки — у второй prev_commission должна быть заполнена
    IF total_rows > 1 THEN
        SELECT prev_commission INTO second_prev
        FROM stepanov_food.how_much_money
        ORDER BY year_month
        OFFSET 1 LIMIT 1;

        IF second_prev IS NULL THEN
            RAISE EXCEPTION 'FAIL [5.10]: second row prev_commission is NULL (recursion not working)';
        END IF;
        RAISE NOTICE 'PASS [5.10]: second row prev_commission = % (recursion working)', second_prev;
    END IF;
END $$;

-- =============================================================================
-- 9. courier_salary() — выполняется без ошибок и обновляет salary_rate (1–5)
-- =============================================================================
DO $$
BEGIN
    CALL stepanov_food.courier_salary();
    RAISE NOTICE 'PASS [5.11]: courier_salary() executed without errors';
END $$;

DO $$
DECLARE bad_count int;
BEGIN
    SELECT count(*) INTO bad_count
    FROM stepanov_food.courier
    WHERE salary_rate < 1 OR salary_rate > 6;

    IF bad_count > 0 THEN
        RAISE EXCEPTION 'FAIL [5.12]: % couriers have salary_rate outside [1,6] after courier_salary()', bad_count;
    END IF;
    RAISE NOTICE 'PASS [5.12]: all couriers have salary_rate in [1,6]';
END $$;

-- =============================================================================
-- 10. courier_salary() — courier_pay получил записи за расчётный период
-- =============================================================================
DO $$
DECLARE v int;
BEGIN
    SELECT count(*) INTO v FROM stepanov_food.courier_pay;
    IF v < 1 THEN
        RAISE EXCEPTION 'FAIL [5.13]: courier_pay is empty after courier_salary()';
    END IF;
    RAISE NOTICE 'PASS [5.13]: courier_pay has % rows after courier_salary()', v;
END $$;

-- =============================================================================
-- 11. courier_salary() — детерминированная проверка бизнес-правила
--     «процент за прошлый месяц».
--     Сценарий: курьер с salary_rate=3 (выставлен в конце прошлого месяца → 20%)
--     делает 5 доставок в текущем месяце по комиссии 100 ₽ каждая.
--     Ожидания:
--       а) оплата за текущий месяц = 5×100 × 20% = 100 ₽
--          (а НЕ 5×100 × 5%=25 ₽ — это была бы старая, неверная логика);
--       б) новый salary_rate = 1 (5 доставок → ставка 1 для следующего месяца).
-- =============================================================================
CALL stepanov_food.erase_test_data();

DO $$
DECLARE
    cur_year       int := extract(year  from current_date)::int;
    cur_month      int := extract(month from current_date)::int;
    v_address_id   uuid := exts.uuid_generate_v4();
    v_client_id    uuid := exts.uuid_generate_v4();
    v_restaurant_id uuid := exts.uuid_generate_v4();
    v_courier_id   uuid := exts.uuid_generate_v4();
    v_order_ts     timestamp := make_timestamp(cur_year, cur_month, 15, 12, 0, 0);
    i              int;
    v_pay          numeric(10,2);
    v_new_rate     int;
BEGIN
    INSERT INTO stepanov_food.address(address_id, street, house_number)
        VALUES (v_address_id, 'Test', '1');
    INSERT INTO stepanov_food.client(client_id, login, password, phone_number)
        VALUES (v_client_id, 'salary_login', 'p', '+70000000000');
    INSERT INTO stepanov_food.restaurant(
        restaurant_id, restaurant_name, address_id,
        open_time, close_time, status
    ) VALUES (
        v_restaurant_id, 'Test', v_address_id,
        '08:00', '22:00', 'открыт'
    );
    INSERT INTO stepanov_food.courier(
        courier_id, last_name, first_name, phone_number, status, hire_date, salary_rate
    ) VALUES (
        v_courier_id, 'Test', 'Test', '+70000000001', 'свободен', current_date, 3
    );

    -- order_amount=1000 → commission=100 (10%, GENERATED) → 5×100=500 ₽ комиссии за месяц.
    FOR i IN 1..5 LOOP
        INSERT INTO stepanov_food."order"(
            order_id, courier_id, client_id, address_id, restaurant_id,
            order_timestamp, order_amount, status
        ) VALUES (
            exts.uuid_generate_v4(), v_courier_id, v_client_id,
            v_address_id, v_restaurant_id,
            v_order_ts, 1000, 'доставлен'
        );
    END LOOP;

    CALL stepanov_food.courier_salary();

    SELECT amount INTO v_pay
    FROM stepanov_food.courier_pay
    WHERE courier_id = v_courier_id
      AND year = cur_year AND month = cur_month;

    IF v_pay IS NULL THEN
        RAISE EXCEPTION 'FAIL [5.14]: courier_pay row not created for billing month';
    END IF;
    IF v_pay <> 100.00 THEN
        RAISE EXCEPTION 'FAIL [5.14]: pay = % (expected 100.00 = 5×100×20%% по СТАРОЙ ставке salary_rate=3). Если получили 25.00 — процент берётся из текущих доставок, а должен из salary_rate.', v_pay;
    END IF;
    RAISE NOTICE 'PASS [5.14]: pay = 100.00 — процент взят из существующего salary_rate (за прошлый месяц)';

    SELECT salary_rate INTO v_new_rate
    FROM stepanov_food.courier WHERE courier_id = v_courier_id;
    IF v_new_rate <> 1 THEN
        RAISE EXCEPTION 'FAIL [5.15]: new salary_rate = % (expected 1 — 5 доставок текущего месяца попадают в диапазон 0–100)', v_new_rate;
    END IF;
    RAISE NOTICE 'PASS [5.15]: new salary_rate = 1 — рассчитан по доставкам текущего месяца (для следующего месяца)';
END $$;

-- =============================================================================
-- Очистка
-- =============================================================================
CALL stepanov_food.erase_test_data();

-- =============================================================================
DO $$ BEGIN RAISE NOTICE '=== ALL STAGE 5 TESTS PASSED ==='; END $$;
