-- =============================================================================
-- test_stage_3.sql — Этап 3: add_product(), триггер rating_change()
-- Запуск: ./run_tests.sh test_stage_3
-- =============================================================================

-- =============================================================================
-- 1. Процедура add_product существует в схеме stepanov_food
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'stepanov_food' AND p.proname = 'add_product'
    ) THEN
        RAISE EXCEPTION 'FAIL [3.1]: procedure stepanov_food.add_product does not exist';
    END IF;
    RAISE NOTICE 'PASS [3.1]: add_product exists';
END $$;

-- =============================================================================
-- 2. Триггерная функция rating_change существует
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'stepanov_food'
          AND p.proname = 'rating_change'
          AND p.prorettype = 'trigger'::regtype
    ) THEN
        RAISE EXCEPTION 'FAIL [3.2]: trigger function stepanov_food.rating_change() does not exist';
    END IF;
    RAISE NOTICE 'PASS [3.2]: trigger function rating_change exists';
END $$;

-- =============================================================================
-- 3. Триггер на таблице review существует и привязан к rating_change
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_proc p ON p.oid = t.tgfoid
        WHERE n.nspname = 'stepanov_food'
          AND c.relname = 'review'
          AND p.proname = 'rating_change'
          AND t.tgtype & 4 > 0   -- AFTER (bit 2)
          AND t.tgtype & 1 > 0   -- ROW-level (bit 0)
          AND NOT t.tgisinternal
    ) THEN
        RAISE EXCEPTION 'FAIL [3.3]: AFTER ROW trigger using rating_change not found on stepanov_food.review';
    END IF;
    RAISE NOTICE 'PASS [3.3]: AFTER ROW trigger rating_change is attached to review';
END $$;

-- =============================================================================
-- Вспомогательные данные для тестов 4–9 (вставляем в транзакцию, откатываем)
-- =============================================================================
BEGIN;

DO $$
DECLARE
    v_addr_id    uuid;
    v_cat_id     uuid;
    v_rest_id    uuid;
    v_prod_id    uuid;
    v_client_id  uuid;
    v_courier_id uuid;
    v_order_id   uuid;
    v_count      int;
    v_rating     numeric;
BEGIN
    -- -------------------------------------------------------------------------
    -- Подготовка тестовых строк
    -- -------------------------------------------------------------------------
    INSERT INTO stepanov_food.address(street, house_number)
    VALUES ('Тестовая', '1') RETURNING address_id INTO v_addr_id;

    INSERT INTO stepanov_food.product_category(product_category_name)
    VALUES ('Тест-категория') RETURNING product_category_id INTO v_cat_id;

    INSERT INTO stepanov_food.restaurant(restaurant_name, address_id, open_time, close_time, rating, status)
    VALUES ('Тест-ресторан', v_addr_id, '10:00'::time, '22:00'::time, 0, 'открыт')
    RETURNING restaurant_id INTO v_rest_id;

    INSERT INTO stepanov_food.client(login, password, phone_number)
    VALUES ('test_user', 'hashed_pass', '+79990000001')
    RETURNING client_id INTO v_client_id;

    INSERT INTO stepanov_food.courier(last_name, first_name, phone_number, status, hire_date)
    VALUES ('Тест', 'Курьер', '+79990000002', 'свободен', current_date)
    RETURNING courier_id INTO v_courier_id;

    -- =========================================================================
    -- ТЕСТ 4: add_product — успешная вставка
    -- =========================================================================
    CALL stepanov_food.add_product(
        'Тест-блюдо',      -- product_name
        v_cat_id,          -- product_category_id
        350.00,            -- price
        v_rest_id,         -- restaurant_id
        NULL,              -- photo_url
        0,                 -- rating
        'доступен',        -- status
        'Описание'         -- description
    );

    SELECT COUNT(*) INTO v_count
    FROM stepanov_food.product
    WHERE product_name = 'Тест-блюдо' AND restaurant_id = v_rest_id;

    IF v_count <> 1 THEN
        RAISE EXCEPTION 'FAIL [3.4]: add_product did not insert a row (count=%)' , v_count;
    END IF;
    RAISE NOTICE 'PASS [3.4]: add_product inserts valid product';

    SELECT product_id INTO v_prod_id
    FROM stepanov_food.product
    WHERE product_name = 'Тест-блюдо' AND restaurant_id = v_rest_id;

    -- =========================================================================
    -- ТЕСТ 5: add_product — UUID генерируется автоматически (не NULL)
    -- =========================================================================
    IF v_prod_id IS NULL THEN
        RAISE EXCEPTION 'FAIL [3.5]: add_product did not generate product_id (NULL)';
    END IF;
    RAISE NOTICE 'PASS [3.5]: add_product auto-generates product_id=%', v_prod_id;

    -- =========================================================================
    -- ТЕСТ 6: add_product — отклонение невалидной цены (price <= 0)
    -- =========================================================================
    BEGIN
        CALL stepanov_food.add_product(
            'Плохое-блюдо', v_cat_id, -1.00, v_rest_id, NULL, 0, 'доступен', NULL
        );
        RAISE EXCEPTION 'FAIL [3.6]: add_product accepted negative price — CHECK constraint missing';
    EXCEPTION
        WHEN check_violation OR raise_exception THEN
            RAISE NOTICE 'PASS [3.6]: add_product rejects price <= 0';
    END;

    -- =========================================================================
    -- ТЕСТ 7: add_product — отклонение несуществующего restaurant_id (FK)
    -- =========================================================================
    BEGIN
        CALL stepanov_food.add_product(
            'Чужое-блюдо', v_cat_id, 100.00, exts.uuid_generate_v4(), NULL, 0, 'доступен', NULL
        );
        RAISE EXCEPTION 'FAIL [3.7]: add_product accepted non-existent restaurant_id — FK missing';
    EXCEPTION
        WHEN foreign_key_violation OR raise_exception THEN
            RAISE NOTICE 'PASS [3.7]: add_product rejects invalid restaurant_id';
    END;

    -- =========================================================================
    -- Подготовка заказа для тестов триггера
    -- =========================================================================
    INSERT INTO stepanov_food."order"(
        courier_id, client_id, address_id, restaurant_id,
        order_amount, status
    ) VALUES (
        v_courier_id, v_client_id, v_addr_id, v_rest_id,
        1000.00, 'доставлен'
    ) RETURNING order_id INTO v_order_id;

    -- =========================================================================
    -- ТЕСТ 8: триггер rating_change пересчитывает рейтинг ресторана
    -- Вставляем 3 отзыва (4, 5, 3) → avg = 4.00
    -- =========================================================================
    INSERT INTO stepanov_food.review(client_id, entity_id, entity_type, order_id, rating)
    VALUES (v_client_id, v_rest_id, 'restaurant', v_order_id, 4);

    INSERT INTO stepanov_food.review(client_id, entity_id, entity_type, order_id, rating)
    VALUES (v_client_id, v_rest_id, 'restaurant', v_order_id, 5);

    INSERT INTO stepanov_food.review(client_id, entity_id, entity_type, order_id, rating)
    VALUES (v_client_id, v_rest_id, 'restaurant', v_order_id, 3);

    SELECT rating INTO v_rating
    FROM stepanov_food.restaurant
    WHERE restaurant_id = v_rest_id;

    IF round(v_rating, 2) <> 4.00 THEN
        RAISE EXCEPTION 'FAIL [3.8]: restaurant rating expected 4.00 after reviews (4+5+3)/3, got %', v_rating;
    END IF;
    RAISE NOTICE 'PASS [3.8]: restaurant rating correctly recalculated to % after 3 reviews', v_rating;

    -- =========================================================================
    -- ТЕСТ 9: триггер rating_change пересчитывает рейтинг блюда
    -- Вставляем 2 отзыва (2, 4) → avg = 3.00
    -- =========================================================================
    INSERT INTO stepanov_food.review(client_id, entity_id, entity_type, order_id, rating)
    VALUES (v_client_id, v_prod_id, 'product', v_order_id, 2);

    INSERT INTO stepanov_food.review(client_id, entity_id, entity_type, order_id, rating)
    VALUES (v_client_id, v_prod_id, 'product', v_order_id, 4);

    SELECT rating INTO v_rating
    FROM stepanov_food.product
    WHERE product_id = v_prod_id;

    IF round(v_rating, 2) <> 3.00 THEN
        RAISE EXCEPTION 'FAIL [3.9]: product rating expected 3.00 after reviews (2+4)/2, got %', v_rating;
    END IF;
    RAISE NOTICE 'PASS [3.9]: product rating correctly recalculated to % after 2 reviews', v_rating;

    -- =========================================================================
    -- ТЕСТ 10: триггер rating_change пересчитывает рейтинг заказа
    -- Вставляем 2 отзыва (3, 5) → avg = 4.00
    -- =========================================================================
    INSERT INTO stepanov_food.review(client_id, entity_id, entity_type, order_id, rating)
    VALUES (v_client_id, v_order_id, 'order', v_order_id, 3);

    INSERT INTO stepanov_food.review(client_id, entity_id, entity_type, order_id, rating)
    VALUES (v_client_id, v_order_id, 'order', v_order_id, 5);

    SELECT rating INTO v_rating
    FROM stepanov_food."order"
    WHERE order_id = v_order_id;

    IF round(v_rating, 2) <> 4.00 THEN
        RAISE EXCEPTION 'FAIL [3.10]: order rating expected 4.00 after reviews (3+5)/2, got %', v_rating;
    END IF;
    RAISE NOTICE 'PASS [3.10]: order rating correctly recalculated to % after 2 reviews', v_rating;

END $$;

ROLLBACK;

-- =============================================================================
DO $$ BEGIN RAISE NOTICE '=== ALL STAGE 3 TESTS PASSED ==='; END $$;
