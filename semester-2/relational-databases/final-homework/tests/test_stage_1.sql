-- =============================================================================
-- test_stage_1.sql — Этап 1: схемы, расширения, ENUM-типы, пользователь reviewer
-- Запуск: ./run_tests.sh test_stage_1
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Схема stepanov_food
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_namespace WHERE nspname = 'stepanov_food'
    ) THEN
        RAISE EXCEPTION 'FAIL [1.1]: schema stepanov_food does not exist';
    END IF;
    RAISE NOTICE 'PASS [1.1]: schema stepanov_food exists';
END $$;

-- ---------------------------------------------------------------------------
-- 2. Схема exts
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_namespace WHERE nspname = 'exts'
    ) THEN
        RAISE EXCEPTION 'FAIL [1.2]: schema exts does not exist';
    END IF;
    RAISE NOTICE 'PASS [1.2]: schema exts exists';
END $$;

-- ---------------------------------------------------------------------------
-- 3. Расширение uuid-ossp установлено именно в схеме exts
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_extension e
        JOIN pg_namespace n ON n.oid = e.extnamespace
        WHERE e.extname = 'uuid-ossp' AND n.nspname = 'exts'
    ) THEN
        RAISE EXCEPTION 'FAIL [1.3]: extension uuid-ossp is not installed in schema exts';
    END IF;
    RAISE NOTICE 'PASS [1.3]: extension uuid-ossp installed in schema exts';
END $$;

-- ---------------------------------------------------------------------------
-- 4. exts.uuid_generate_v4() вызывается и возвращает ненулевой UUID
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    v uuid;
BEGIN
    v := exts.uuid_generate_v4();
    IF v IS NULL THEN
        RAISE EXCEPTION 'FAIL [1.4]: exts.uuid_generate_v4() returned NULL';
    END IF;
    RAISE NOTICE 'PASS [1.4]: exts.uuid_generate_v4() works, sample=%', v;
END $$;

-- ---------------------------------------------------------------------------
-- 5-10. Все ENUM-типы существуют в схеме stepanov_food
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    enum_names text[] := ARRAY[
        'courier_status',
        'restaurant_status',
        'product_status',
        'order_status',
        'pay_type',
        'payment_status'
    ];
    t text;
BEGIN
    FOREACH t IN ARRAY enum_names LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_type tp
            JOIN pg_namespace n ON n.oid = tp.typnamespace
            WHERE tp.typname = t
              AND n.nspname = 'stepanov_food'
              AND tp.typtype = 'e'
        ) THEN
            RAISE EXCEPTION 'FAIL [1.5-%]: ENUM type stepanov_food.% does not exist', t, t;
        END IF;
        RAISE NOTICE 'PASS [1.5-%]: ENUM type stepanov_food.% exists', t, t;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 11. Каждый ENUM-тип содержит хотя бы 2 значения (не пустой)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    enum_names text[] := ARRAY[
        'courier_status',
        'restaurant_status',
        'product_status',
        'order_status',
        'pay_type',
        'payment_status'
    ];
    t text;
    cnt int;
BEGIN
    FOREACH t IN ARRAY enum_names LOOP
        SELECT count(*) INTO cnt
        FROM pg_enum e
        JOIN pg_type tp ON tp.oid = e.enumtypid
        JOIN pg_namespace n ON n.oid = tp.typnamespace
        WHERE tp.typname = t AND n.nspname = 'stepanov_food';

        IF cnt < 2 THEN
            RAISE EXCEPTION 'FAIL [1.6-%]: ENUM type stepanov_food.% has fewer than 2 labels (got %)', t, t, cnt;
        END IF;
        RAISE NOTICE 'PASS [1.6-%]: ENUM type stepanov_food.% has % labels', t, t, cnt;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 12. Пользователь reviewer существует
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'reviewer'
    ) THEN
        RAISE EXCEPTION 'FAIL [1.7]: role reviewer does not exist';
    END IF;
    RAISE NOTICE 'PASS [1.7]: role reviewer exists';
END $$;

-- ---------------------------------------------------------------------------
-- 13. reviewer НЕ является суперпользователем (принцип минимальных привилегий)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'reviewer' AND rolsuper = true
    ) THEN
        RAISE EXCEPTION 'FAIL [1.8]: reviewer must not be a superuser';
    END IF;
    RAISE NOTICE 'PASS [1.8]: reviewer is not a superuser';
END $$;

-- ---------------------------------------------------------------------------
-- 14. reviewer имеет USAGE на схему stepanov_food
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT has_schema_privilege('reviewer', 'stepanov_food', 'USAGE') THEN
        RAISE EXCEPTION 'FAIL [1.9]: reviewer does not have USAGE on stepanov_food';
    END IF;
    RAISE NOTICE 'PASS [1.9]: reviewer has USAGE on stepanov_food';
END $$;

-- ---------------------------------------------------------------------------
-- 15. reviewer имеет CREATE на схему stepanov_food (полный доступ)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT has_schema_privilege('reviewer', 'stepanov_food', 'CREATE') THEN
        RAISE EXCEPTION 'FAIL [1.10]: reviewer does not have CREATE on stepanov_food';
    END IF;
    RAISE NOTICE 'PASS [1.10]: reviewer has CREATE on stepanov_food';
END $$;

-- ---------------------------------------------------------------------------
-- 16. reviewer имеет USAGE на схему exts (для вызова uuid_generate_v4)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT has_schema_privilege('reviewer', 'exts', 'USAGE') THEN
        RAISE EXCEPTION 'FAIL [1.11]: reviewer does not have USAGE on exts';
    END IF;
    RAISE NOTICE 'PASS [1.11]: reviewer has USAGE on exts';
END $$;

-- ---------------------------------------------------------------------------
-- 17. reviewer может читать pg_catalog (USAGE)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT has_schema_privilege('reviewer', 'pg_catalog', 'USAGE') THEN
        RAISE EXCEPTION 'FAIL [1.12]: reviewer does not have USAGE on pg_catalog';
    END IF;
    RAISE NOTICE 'PASS [1.12]: reviewer has USAGE on pg_catalog';
END $$;

-- ---------------------------------------------------------------------------
-- 18. reviewer может читать information_schema (USAGE)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT has_schema_privilege('reviewer', 'information_schema', 'USAGE') THEN
        RAISE EXCEPTION 'FAIL [1.13]: reviewer does not have USAGE on information_schema';
    END IF;
    RAISE NOTICE 'PASS [1.13]: reviewer has USAGE on information_schema';
END $$;

-- ---------------------------------------------------------------------------
-- 19. reviewer НЕ имеет CREATE на pg_catalog (только чтение)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF has_schema_privilege('reviewer', 'pg_catalog', 'CREATE') THEN
        RAISE EXCEPTION 'FAIL [1.14]: reviewer must NOT have CREATE on pg_catalog (read-only)';
    END IF;
    RAISE NOTICE 'PASS [1.14]: reviewer does not have CREATE on pg_catalog';
END $$;

-- ---------------------------------------------------------------------------
-- 20. reviewer НЕ имеет CREATE на information_schema (только чтение)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF has_schema_privilege('reviewer', 'information_schema', 'CREATE') THEN
        RAISE EXCEPTION 'FAIL [1.15]: reviewer must NOT have CREATE on information_schema (read-only)';
    END IF;
    RAISE NOTICE 'PASS [1.15]: reviewer does not have CREATE on information_schema';
END $$;

-- ---------------------------------------------------------------------------
-- Итог
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '=== ALL STAGE 1 TESTS PASSED ===';
END $$;
