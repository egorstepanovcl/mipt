-- =============================================================================
-- verify.sql — Ручная проверка по критериям оценки
-- Запуск: docker compose exec -T db psql -U postgres -d postgres -f /tests/verify.sql
-- =============================================================================

\echo ''
\echo '============================================================'
\echo '  STEPANOV FOOD — ПРОВЕРКА ПО КРИТЕРИЯМ ОЦЕНКИ'
\echo '============================================================'

-- =============================================================================
\echo ''
\echo '------------------------------------------------------------'
\echo '  КРИТЕРИЙ 1: Пользователь reviewer, резервная копия, типы'
\echo '------------------------------------------------------------'

\echo ''
\echo '-- Роль reviewer:'
SELECT rolname, rolcanlogin, rolsuper
FROM pg_roles
WHERE rolname = 'reviewer';

\echo ''
\echo '-- Права reviewer на схему stepanov_food:'
SELECT
    nspname                          AS schema,
    has_schema_privilege('reviewer', nspname, 'USAGE')  AS usage,
    has_schema_privilege('reviewer', nspname, 'CREATE') AS create
FROM pg_namespace
WHERE nspname IN ('stepanov_food', 'exts', 'pg_catalog', 'information_schema');

\echo ''
\echo '-- ENUM-типы в stepanov_food:'
SELECT
    t.typname            AS enum_name,
    array_agg(e.enumlabel ORDER BY e.enumsortorder) AS values
FROM pg_type t
JOIN pg_namespace n ON n.oid = t.typnamespace
JOIN pg_enum e ON e.enumtypid = t.oid
WHERE n.nspname = 'stepanov_food'
GROUP BY t.typname
ORDER BY t.typname;

\echo ''
\echo '-- Расширение uuid-ossp в схеме exts:'
SELECT extname, n.nspname AS schema
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
WHERE extname = 'uuid-ossp';

-- =============================================================================
\echo ''
\echo '------------------------------------------------------------'
\echo '  КРИТЕРИЙ 2: Физическая схема (таблицы, 3НФ, связи)'
\echo '------------------------------------------------------------'

\echo ''
\echo '-- Все таблицы схемы stepanov_food:'
SELECT
    c.relname                                   AS table_name,
    COUNT(a.attnum)                             AS columns,
    obj_description(c.oid, 'pg_class')          AS comment
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
WHERE n.nspname = 'stepanov_food' AND c.relkind = 'r'
GROUP BY c.relname, c.oid
ORDER BY c.relname;

\echo ''
\echo '-- Внешние ключи (все 14):'
SELECT
    kcu.table_name   AS from_table,
    kcu.column_name  AS from_column,
    ccu.table_name   AS to_table,
    ccu.column_name  AS to_column,
    rc.delete_rule   AS on_delete
FROM information_schema.referential_constraints rc
JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = rc.constraint_name
   AND kcu.constraint_schema = rc.constraint_schema
JOIN information_schema.key_column_usage ccu
    ON ccu.constraint_name  = rc.unique_constraint_name
   AND ccu.constraint_schema = rc.unique_constraint_schema
WHERE kcu.table_schema = 'stepanov_food'
ORDER BY kcu.table_name, kcu.column_name;

-- =============================================================================
\echo ''
\echo '------------------------------------------------------------'
\echo '  КРИТЕРИЙ 3: insert_test_data(value) и erase_test_data()'
\echo '------------------------------------------------------------'

-- Чистый старт
CALL stepanov_food.erase_test_data();
CALL stepanov_food.insert_test_data(5);

\echo ''
\echo '-- Количество строк после insert_test_data(5):'
SELECT 'client'           AS tbl, count(*) AS rows FROM stepanov_food.client
UNION ALL
SELECT 'courier',                  count(*) FROM stepanov_food.courier
UNION ALL
SELECT 'product_category',         count(*) FROM stepanov_food.product_category
UNION ALL
SELECT 'restaurant',               count(*) FROM stepanov_food.restaurant
UNION ALL
SELECT 'address',                  count(*) FROM stepanov_food.address
UNION ALL
SELECT 'product',                  count(*) FROM stepanov_food.product
UNION ALL
SELECT '"order"',                  count(*) FROM stepanov_food."order"
UNION ALL
SELECT 'review',                   count(*) FROM stepanov_food.review
UNION ALL
SELECT 'client_address',           count(*) FROM stepanov_food.client_address
UNION ALL
SELECT 'order_structure',          count(*) FROM stepanov_food.order_structure
UNION ALL
SELECT 'courier_pay',              count(*) FROM stepanov_food.courier_pay
ORDER BY tbl;

\echo ''
\echo '-- Примеры сгенерированных заказов (3 строки):'
SELECT
    o.order_id,
    c.login              AS client,
    r.restaurant_name,
    o.order_amount,
    o.commission,
    o.total_amount,
    o.status,
    to_char(o.order_timestamp, 'YYYY-MM-DD HH24:MI') AS ordered_at
FROM stepanov_food."order" o
JOIN stepanov_food.client     c ON c.client_id     = o.client_id
JOIN stepanov_food.restaurant r ON r.restaurant_id = o.restaurant_id
ORDER BY o.order_timestamp DESC
LIMIT 3;

-- =============================================================================
\echo ''
\echo '------------------------------------------------------------'
\echo '  КРИТЕРИЙ 4: Триггер rating_change()'
\echo '------------------------------------------------------------'

\echo ''
\echo '-- Рейтинги ресторанов ДО добавления отзывов:'
SELECT restaurant_name, rating FROM stepanov_food.restaurant ORDER BY restaurant_name LIMIT 3;

\echo ''
\echo '-- Добавляем по 3 отзыва для первых двух ресторанов...'
DO $$
DECLARE
    v_rest1  uuid;
    v_rest2  uuid;
    v_client uuid;
    v_order  uuid;
BEGIN
    SELECT restaurant_id INTO v_rest1 FROM stepanov_food.restaurant ORDER BY restaurant_name LIMIT 1;
    SELECT restaurant_id INTO v_rest2 FROM stepanov_food.restaurant ORDER BY restaurant_name OFFSET 1 LIMIT 1;
    SELECT client_id     INTO v_client FROM stepanov_food.client ORDER BY random() LIMIT 1;
    SELECT order_id      INTO v_order  FROM stepanov_food."order" ORDER BY random() LIMIT 1;

    INSERT INTO stepanov_food.review(review_id, client_id, entity_id, entity_type, order_id, rating)
    VALUES
        (exts.uuid_generate_v4(), v_client, v_rest1, 'restaurant', v_order, 4),
        (exts.uuid_generate_v4(), v_client, v_rest1, 'restaurant', v_order, 5),
        (exts.uuid_generate_v4(), v_client, v_rest1, 'restaurant', v_order, 3),
        (exts.uuid_generate_v4(), v_client, v_rest2, 'restaurant', v_order, 2),
        (exts.uuid_generate_v4(), v_client, v_rest2, 'restaurant', v_order, 4),
        (exts.uuid_generate_v4(), v_client, v_rest2, 'restaurant', v_order, 4);
END $$;

\echo ''
\echo '-- Рейтинги ресторанов ПОСЛЕ отзывов (триггер пересчитал):'
SELECT restaurant_name, rating FROM stepanov_food.restaurant ORDER BY restaurant_name LIMIT 3;

-- =============================================================================
\echo ''
\echo '------------------------------------------------------------'
\echo '  КРИТЕРИЙ 5: Процедура add_product(...)'
\echo '------------------------------------------------------------'

\echo ''
\echo '-- Количество продуктов ДО:'
SELECT count(*) AS products_before FROM stepanov_food.product;

DO $$
DECLARE
    v_cat_id  uuid;
    v_rest_id uuid;
BEGIN
    SELECT product_category_id INTO v_cat_id  FROM stepanov_food.product_category ORDER BY random() LIMIT 1;
    SELECT restaurant_id       INTO v_rest_id FROM stepanov_food.restaurant        ORDER BY random() LIMIT 1;
    CALL stepanov_food.add_product(
        'Фирменный бургер',
        v_cat_id,
        499.00,
        v_rest_id,
        'https://cdn.example.com/burger.jpg',
        0,
        'доступен',
        'Сочный бургер с говядиной и сыром'
    );
END $$;

\echo ''
\echo '-- Новый продукт добавлен:'
SELECT product_id, product_name, price, status, description
FROM stepanov_food.product
WHERE product_name = 'Фирменный бургер';

\echo ''
\echo '-- Количество продуктов ПОСЛЕ: должно быть +1'
SELECT count(*) AS products_after FROM stepanov_food.product;

-- =============================================================================
\echo ''
\echo '------------------------------------------------------------'
\echo '  КРИТЕРИЙ 6: Функция get_statistic()'
\echo '------------------------------------------------------------'

\echo ''
\echo '-- Статистика по ресторанам:'
SELECT
    restaurant_name,
    best_product_name,
    total_amount,
    avg_amount,
    best_user
FROM stepanov_food.get_statistic();

-- =============================================================================
\echo ''
\echo '------------------------------------------------------------'
\echo '  КРИТЕРИЙ 7: Процедура courier_salary()'
\echo '------------------------------------------------------------'

\echo ''
\echo '-- Ставки курьеров ДО вызова courier_salary():'
SELECT courier_id, last_name || ' ' || first_name AS fio, salary_rate FROM stepanov_food.courier ORDER BY last_name, first_name;

CALL stepanov_food.courier_salary();

\echo ''
\echo '-- Ставки курьеров ПОСЛЕ (обновлены по числу доставок в текущем месяце):'
SELECT courier_id, last_name || ' ' || first_name AS fio, salary_rate FROM stepanov_food.courier ORDER BY last_name, first_name;

\echo ''
\echo '-- Записи courier_pay за текущий месяц:'
SELECT
    cr.last_name || ' ' || cr.first_name AS fio,
    cp.year,
    cp.month,
    cp.amount,
    (SELECT count(*) FROM stepanov_food."order" o
     WHERE o.courier_id = cp.courier_id
       AND extract(year  FROM o.order_timestamp) = cp.year
       AND extract(month FROM o.order_timestamp) = cp.month
    ) AS deliveries_this_month
FROM stepanov_food.courier_pay cp
JOIN stepanov_food.courier cr ON cr.courier_id = cp.courier_id
WHERE cp.year  = extract(year  FROM current_date)
  AND cp.month = extract(month FROM current_date)
ORDER BY cr.last_name, cr.first_name;

-- =============================================================================
\echo ''
\echo '------------------------------------------------------------'
\echo '  КРИТЕРИЙ 8: Представление how_much_money (рекурсия)'
\echo '------------------------------------------------------------'

\echo ''
SELECT
    year_month,
    total_without_commission,
    total_with_commission,
    total_commission,
    prev_commission,
    commission_diff,
    courier_total_pay,
    net_profit
FROM stepanov_food.how_much_money;

\echo ''
\echo '============================================================'
\echo '  ПРОВЕРКА ЗАВЕРШЕНА  '
\echo '============================================================'
