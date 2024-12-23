SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

-- Сначала дропаем все что может быть
DROP SCHEMA IF EXISTS tables CASCADE;
DROP SCHEMA IF EXISTS procedures CASCADE;
DROP SCHEMA IF EXISTS init CASCADE;
DROP DATABASE IF EXISTS med_database;
DROP ROLE IF EXISTS med_user;

-- Создаем пользователя с ограниченными правами для использования
CREATE USER med_user WITH PASSWORD 'qwerty';

-- Создаем базу данных
CREATE DATABASE med_database OWNER med_procedures_owner;

-- Подключаемся к базе данных
\c med_database

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

-- Создаем схему для таблиц
CREATE SCHEMA tables;

-- Создаем схему для процедур и функций
CREATE SCHEMA procedures;

-- Создаем схему для инициализации
CREATE SCHEMA init;

-- Установим search_path
ALTER DATABASE med_database SET search_path TO tables, procedures, init, public;

-- Ограничиваем привилегии для med_user и для новых юзеров
REVOKE ALL ON DATABASE med_database FROM PUBLIC;
GRANT CONNECT ON DATABASE med_database TO med_user;

-- Переходим в схему таблиц и создаем там все таблицы
SET search_path TO tables, procedures, init, public;

-- Назначаем med_procedures_owner права на схемы
ALTER SCHEMA tables OWNER TO med_procedures_owner;
ALTER SCHEMA procedures OWNER TO med_procedures_owner;
ALTER SCHEMA init OWNER TO med_procedures_owner;

-- Таблица "Пациенты"
CREATE TABLE tables.patients (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    birth_date DATE NOT NULL,
    contacts VARCHAR(255),
    passport_data VARCHAR(50) NOT NULL,
    insurance_policy_number VARCHAR(50) NOT NULL
);

-- Таблица "Поликлиника"
CREATE TABLE tables.clinic (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL
);

-- Таблица "Доктора"
CREATE TABLE tables.doctors (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    specialization VARCHAR(100) NOT NULL,
    contacts VARCHAR(255),
    clinic_id INT NOT NULL REFERENCES tables.clinic(id) ON DELETE CASCADE
);

-- Таблица "Записи на прием"
CREATE TABLE tables.appointments (
    id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES tables.patients(id) ON DELETE CASCADE,
    doctor_id INT REFERENCES tables.doctors(id) ON DELETE CASCADE,
    appointment_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'запланировано',
    clinic_id INT REFERENCES tables.clinic(id) ON DELETE CASCADE,
    CONSTRAINT chk_status CHECK (status IN ('запланировано', 'пропущено', 'отменено', 'завершено'))
);

-- Таблица "Медицинская книжка"
CREATE TABLE tables.medical_records (
    id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES tables.patients(id) ON DELETE CASCADE,
    conclusion TEXT NOT NULL,
    record_date DATE NOT NULL
);

ALTER TABLE tables.clinic OWNER TO med_procedures_owner;
ALTER TABLE tables.patients OWNER TO med_procedures_owner;
ALTER TABLE tables.doctors OWNER TO med_procedures_owner;
ALTER TABLE tables.appointments OWNER TO med_procedures_owner;
ALTER TABLE tables.medical_records OWNER TO med_procedures_owner;
-- Для ускорения поиска по имени пациента создаем индекс:
CREATE INDEX idx_patients_full_name ON tables.patients(full_name);

-- Добавляем поле age (возраст) как производное
ALTER TABLE tables.patients ADD COLUMN age INT;

-- Переходим в схему procedures
SET search_path TO procedures, tables, init, public;

-- Функция для расчета возраста
CREATE OR REPLACE FUNCTION procedures.calculate_age()
RETURNS TRIGGER
AS $$
BEGIN
    NEW.age := DATE_PART('year', AGE(NEW.birth_date));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для расчета возраста
CREATE TRIGGER trigger_calculate_age
BEFORE INSERT OR UPDATE ON tables.patients
FOR EACH ROW
EXECUTE FUNCTION procedures.calculate_age();

-- Триггер для изменения статуса записи
CREATE OR REPLACE FUNCTION procedures.update_appointment_status()
RETURNS TRIGGER
AS $$
BEGIN
    IF NEW.appointment_date < CURRENT_DATE AND NEW.status = 'запланировано' THEN
        NEW.status := 'пропущено';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для обновления статуса записи
CREATE TRIGGER trigger_update_status
BEFORE INSERT OR UPDATE ON tables.appointments
FOR EACH ROW
EXECUTE FUNCTION procedures.update_appointment_status();

-- Процедура поиска записи по ключу
CREATE OR REPLACE FUNCTION procedures.search_by_key(
    table_name TEXT,
    column_name TEXT,
    search_value TEXT
)
RETURNS TABLE(result JSON)
AS $$
BEGIN
    RETURN QUERY EXECUTE FORMAT(
        'SELECT row_to_json(t) FROM tables.%I t WHERE %I = %L',
        table_name,
        column_name,
        search_value
    );
END;
$$ LANGUAGE plpgsql;

/* Пример:
SELECT * FROM procedures.search_by_key('patients', 'full_name', 'Алексеева Анна Сергеевна');
*/

-- Процедура удаления записи
CREATE OR REPLACE PROCEDURE procedures.delete_record(table_name TEXT, column_name TEXT, key_value TEXT)
LANGUAGE plpgsql
SECURITY DEFINER -- заставит процедуру выполняться с привилегиями владельца функции, т.к у med_user нету права на DELETE
AS $$
BEGIN
    EXECUTE format('DELETE FROM tables.%I WHERE %I = %L', table_name, column_name, key_value);
END;
$$;
-- Пример: CALL procedures.delete_record('patients', 'id', '1');

-- Процедура вставки данных
CREATE OR REPLACE PROCEDURE procedures.insert_into_table(table_name TEXT, columns TEXT[], info TEXT[])
AS $$
BEGIN
    EXECUTE format(
        'INSERT INTO tables.%I (%s) VALUES (%s)',
        table_name,
        array_to_string(columns, ', '),
        array_to_string(ARRAY(SELECT quote_literal(x) FROM unnest(info) AS x), ', ')
    );
END;
$$ LANGUAGE plpgsql;

/* Пример:
CALL procedures.insert_into_table(
    'patients',
    ARRAY['full_name', 'birth_date', 'contacts', 'passport_data', 'insurance_policy_number'],
    ARRAY['Иван Иванов', '1980-01-01', '89991234567', '1234 567890', '12345678']
);
*/

-- Процедура изменения записи
CREATE OR REPLACE PROCEDURE procedures.update_record(table_name TEXT, column_name TEXT, new_value TEXT, key_column TEXT, key_value TEXT)
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format('UPDATE tables.%I SET %I = %L WHERE %I = %L',
                   table_name, column_name, new_value, key_column, key_value);
END;
$$;
-- Пример: CALL procedures.update_record('patients', 'contacts', '89991112233', 'id', '1');

-- Процедура для удаления схемы с каскадным удалением всех таблиц
CREATE OR REPLACE PROCEDURE procedures.drop_database_schema()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверка, что текущий пользователь — 'med_procedures_owner'	
    IF current_user != 'med_procedures_owner' THEN
        RAISE EXCEPTION 'Permission denied: this procedure can only be executed by owner';
    END IF;
    
    EXECUTE 'DROP SCHEMA IF EXISTS tables CASCADE';
    RAISE NOTICE 'Схема tables и все связанные таблицы удалены.';
    
    -- Устанавливаем флаг инициализации в FALSE
    UPDATE init.initialization_status SET is_initialized = FALSE;
END;
$$;
-- Пример: CALL procedures.drop_database_schema();

-- Функция для подсчета таблиц
CREATE OR REPLACE FUNCTION procedures.count_tables()
RETURNS INTEGER AS $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'tables';

    RETURN table_count;
END;
$$ LANGUAGE plpgsql;
-- Пример: SELECT procedures.count_tables();

-- Функция для получения заголовков таблицы
CREATE OR REPLACE FUNCTION procedures.get_all_table_headers()
RETURNS JSON AS $$
DECLARE
    headers JSON;
BEGIN
    SELECT json_object_agg(
        table_name,
        column_headers
    )
    INTO headers
    FROM (
        SELECT
            c.table_name,
            json_agg(c.column_name::TEXT ORDER BY c.ordinal_position) AS column_headers
        FROM information_schema.columns AS c
        WHERE c.table_schema = 'tables'
        GROUP BY c.table_name
        ORDER BY c.table_name
    ) subquery;

    RETURN headers;
END;
$$ LANGUAGE plpgsql;
-- Пример: SELECT procedures.get_all_table_headers();

-- Функция для выдачи всех данных из таблицы
CREATE OR REPLACE FUNCTION procedures.get_all_data(table_name TEXT)
RETURNS SETOF JSON AS $$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT row_to_json(t) 
         FROM tables.%I AS t
         ORDER BY t.id', 
        table_name
    );
END;
$$ LANGUAGE plpgsql;
-- Пример: SELECT * FROM procedures.get_all_data('patients');


-- Процедура для очистки конкретной таблицы
CREATE OR REPLACE PROCEDURE procedures.clear_table(table_name_ TEXT)
LANGUAGE plpgsql
SECURITY DEFINER -- выполняется с правами владельца процедуры
AS $$
BEGIN
    -- Проверка существования таблицы
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'tables'
        AND table_name = table_name_
    ) THEN
        RAISE EXCEPTION 'Table %.% does not exist', 'tables', table_name_;
    END IF;

    -- Очистка таблицы
    EXECUTE format('TRUNCATE TABLE tables.%I RESTART IDENTITY CASCADE', table_name_);
    RAISE NOTICE 'Таблица %.% очищена', 'tables', table_name_;
END;
$$;
-- Пример: CALL procedures.clear_table('patients');

-- Процедура для очистки всех таблиц в схеме tables
CREATE OR REPLACE PROCEDURE procedures.clear_all_tables()
LANGUAGE plpgsql
SECURITY DEFINER -- выполняется с правами владельца процедуры
AS $$
DECLARE
    table_name text;
BEGIN
    -- Отключаем проверку внешних ключей на время очистки
    SET CONSTRAINTS ALL DEFERRED;

    -- Перебираем все таблицы в схеме tables
    FOR table_name IN 
        SELECT tables.table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'tables'
    LOOP
        -- Очистка каждой таблицы
        EXECUTE format('TRUNCATE TABLE tables.%I CASCADE', table_name);
        RAISE NOTICE 'Таблица %.% очищена', 'tables', table_name;
    END LOOP;

    -- Включаем обратно проверку внешних ключей
    SET CONSTRAINTS ALL IMMEDIATE;

    RAISE NOTICE 'Все таблицы в схеме tables очищены';
END;
$$;
-- Пример: CALL procedures.clear_all_tables();


-- Процедура для заполнения данными
CREATE OR REPLACE PROCEDURE procedures.seed_data()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверка, что текущий пользователь — 'med_procedures_owner'
    IF current_user != 'med_procedures_owner' THEN
        RAISE EXCEPTION 'Permission denied: this procedure can only be executed by owner';
    END IF;
    
    -- Заполняем таблицу "Поликлиника"
    INSERT INTO tables.clinic (name, address, phone) VALUES
        ('Поликлиника №1', 'г. Нижний Новгород, ул. Ленина, д. 1', '8311234567'),
        ('Поликлиника №2', 'г. Нижний Новгород, ул. Белинского, д. 10', '8312345678'),
        ('Поликлиника №3', 'г. Нижний Новгород, ул. Горького, д. 15', '8313456789');
    RAISE NOTICE 'Таблица clinic заполнена.';

    -- Заполняем таблицу "Доктора"
    INSERT INTO tables.doctors (full_name, specialization, contacts, clinic_id) VALUES
        ('Иванов Иван Иванович', 'Терапевт', '89101234567', 1),
        ('Петров Петр Петрович', 'Хирург', '89109876543', 2),
        ('Сидоров Сидор Сидорович', 'Кардиолог', '89201234567', 3);
    RAISE NOTICE 'Таблица doctors заполнена.';

    -- Заполняем таблицу "Пациенты"
    INSERT INTO tables.patients (full_name, birth_date, contacts, passport_data, insurance_policy_number) VALUES
        ('Алексеева Анна Сергеевна', '1985-05-12', '89031234567', '1234 567890', '12345678'),
        ('Михайлов Михаил Андреевич', '1990-02-28', '89041234567', '2345 678901', '23456789'),
        ('Васильева Василиса Ивановна', '2000-10-15', '89051234567', '3456 789012', '34567890');
    RAISE NOTICE 'Таблица patients заполнена.';

    -- Заполняем таблицу "Записи на прием"
    INSERT INTO tables.appointments (patient_id, doctor_id, appointment_date, status, clinic_id) VALUES
        (1, 1, '2024-12-01', 'запланировано', 1),
        (2, 2, '2024-11-15', 'запланировано', 2),
        (3, 3, '2024-11-10', 'запланировано', 3);
    RAISE NOTICE 'Таблица appointments заполнена.';

    -- Заполняем таблицу "Медицинская книжка"
    INSERT INTO tables.medical_records (patient_id, conclusion, record_date) VALUES
        (1, 'Общее состояние хорошее. Рекомендовано продолжить лечение.', '2024-11-01'),
        (2, 'Необходима операция на коленном суставе.', '2024-11-10'),
        (3, 'Проведена успешная терапия. Пациентка в стабильном состоянии.', '2024-11-05');
    RAISE NOTICE 'Таблица medical_records заполнена.';
END;
$$;
-- Пример: CALL procedures.seed_data();

-- Переходим в схему init
SET search_path TO init, tables, procedures, public;

-- Таблица для хранения состояния инициализации
CREATE TABLE init.initialization_status (
    is_initialized BOOLEAN NOT NULL DEFAULT FALSE
);
-- Добавляем запись со значением по умолчанию (база данных не инициализирована)
INSERT INTO init.initialization_status (is_initialized) VALUES (FALSE);

-- Функция для проверки, проинициализирована ли БД
CREATE OR REPLACE FUNCTION procedures.is_db_initialized()
RETURNS BOOLEAN AS $$
DECLARE
    initialized BOOLEAN;
BEGIN
    SELECT is_initialized INTO initialized FROM init.initialization_status;
    RETURN initialized;
END;
$$ LANGUAGE plpgsql;
-- SELECT procedures.is_db_initialized();


-- Создаем процедуру инициализации в схеме init
ALTER FUNCTION procedures.calculate_age() OWNER TO med_procedures_owner;
ALTER FUNCTION procedures.update_appointment_status() OWNER TO med_procedures_owner;
ALTER FUNCTION procedures.search_by_key(text, text, text) OWNER TO med_procedures_owner;
ALTER PROCEDURE procedures.delete_record(text, text, text) OWNER TO med_procedures_owner;
ALTER PROCEDURE procedures.insert_into_table(text, text[], text[]) OWNER TO med_procedures_owner;
ALTER PROCEDURE procedures.update_record(text, text, text, text, text) OWNER TO med_procedures_owner;
ALTER PROCEDURE procedures.drop_database_schema() OWNER TO med_procedures_owner;
ALTER FUNCTION procedures.count_tables() OWNER TO med_procedures_owner;
ALTER FUNCTION procedures.get_all_table_headers() OWNER TO med_procedures_owner;
ALTER FUNCTION procedures.get_all_data(text) OWNER TO med_procedures_owner;
ALTER PROCEDURE procedures.clear_table(text) OWNER TO med_procedures_owner;
ALTER PROCEDURE procedures.clear_all_tables() OWNER TO med_procedures_owner;
ALTER PROCEDURE procedures.seed_data() OWNER TO med_procedures_owner;

CREATE OR REPLACE PROCEDURE init.initialize_database()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверка, что текущий пользователь — 'med_procedures_owner'
    IF current_user != 'med_procedures_owner' THEN
        RAISE EXCEPTION 'Permission denied: this procedure can only be executed by owner';
    END IF;

    -- Создаем схему для таблиц, если её нет
    CREATE SCHEMA IF NOT EXISTS tables;
    ALTER SCHEMA tables OWNER TO med_procedures_owner;

    -- Таблица "Пациенты"
    CREATE TABLE IF NOT EXISTS tables.patients (
        id SERIAL PRIMARY KEY,
        full_name VARCHAR(255) NOT NULL,
        birth_date DATE NOT NULL,
        contacts VARCHAR(255),
        passport_data VARCHAR(50) NOT NULL,
        insurance_policy_number VARCHAR(50) NOT NULL,
        age INT
    );

    -- Таблица "Поликлиника"
    CREATE TABLE IF NOT EXISTS tables.clinic (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        address VARCHAR(255) NOT NULL,
        phone VARCHAR(20) NOT NULL
    );

    -- Таблица "Доктора"
    CREATE TABLE IF NOT EXISTS tables.doctors (
        id SERIAL PRIMARY KEY,
        full_name VARCHAR(255) NOT NULL,
        specialization VARCHAR(100) NOT NULL,
        contacts VARCHAR(255),
        clinic_id INT NOT NULL REFERENCES tables.clinic(id) ON DELETE CASCADE
    );

    -- Таблица "Записи на прием"
    CREATE TABLE IF NOT EXISTS tables.appointments (
        id SERIAL PRIMARY KEY,
        patient_id INT REFERENCES tables.patients(id) ON DELETE CASCADE,
        doctor_id INT REFERENCES tables.doctors(id) ON DELETE CASCADE,
        appointment_date DATE NOT NULL,
        status VARCHAR(50) DEFAULT 'запланировано',
        clinic_id INT REFERENCES tables.clinic(id) ON DELETE CASCADE,
        CONSTRAINT chk_status CHECK (status IN ('запланировано', 'пропущено', 'отменено', 'завершено'))
    );

    -- Таблица "Медицинская книжка"
    CREATE TABLE IF NOT EXISTS tables.medical_records (
        id SERIAL PRIMARY KEY,
        patient_id INT REFERENCES tables.patients(id) ON DELETE CASCADE,
        conclusion TEXT NOT NULL,
        record_date DATE NOT NULL
    );

    -- Назначаем владельца для всех таблиц
    ALTER TABLE tables.clinic OWNER TO med_procedures_owner;
    ALTER TABLE tables.patients OWNER TO med_procedures_owner;
    ALTER TABLE tables.doctors OWNER TO med_procedures_owner;
    ALTER TABLE tables.appointments OWNER TO med_procedures_owner;
    ALTER TABLE tables.medical_records OWNER TO med_procedures_owner;

    -- Создаем индекс для ускорения поиска по имени пациента, если его нет
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = 'tables' 
        AND tablename = 'patients' 
        AND indexname = 'idx_patients_full_name'
    ) THEN
        CREATE INDEX idx_patients_full_name ON tables.patients(full_name);
    END IF;

    -- Даем пользователю права на схему с таблицами
    GRANT USAGE ON SCHEMA tables TO med_user;
    
    -- Даем права на таблицы
    GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA tables TO med_user;

    -- Даем права на последовательности
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA tables TO med_user;

    -- Даем пользователю права на схему procedures
    GRANT USAGE ON SCHEMA procedures TO med_user;
    
    -- Даем права на отдельные процедуры
    GRANT EXECUTE ON PROCEDURE procedures.delete_record(TEXT, TEXT, TEXT) TO med_user;
    GRANT EXECUTE ON PROCEDURE procedures.insert_into_table(TEXT, TEXT[], TEXT[]) TO med_user;
    GRANT EXECUTE ON PROCEDURE procedures.update_record(TEXT, TEXT, TEXT, TEXT, TEXT) TO med_user;
    GRANT EXECUTE ON PROCEDURE procedures.clear_table(TEXT) to med_user;
    GRANT EXECUTE ON PROCEDURE procedures.clear_all_tables() to med_user;
    GRANT EXECUTE ON FUNCTION procedures.search_by_key(TEXT, TEXT, TEXT) TO med_user;
    GRANT EXECUTE ON FUNCTION procedures.count_tables() TO med_user;
    GRANT EXECUTE ON FUNCTION procedures.get_all_table_headers() TO med_user;
    GRANT EXECUTE ON FUNCTION procedures.get_all_data(TEXT) TO med_user;
    REVOKE EXECUTE ON PROCEDURE procedures.seed_data() FROM med_user;
    REVOKE EXECUTE ON PROCEDURE procedures.drop_database_schema() FROM med_user;
    
    -- Пересоздаем триггеры
    -- Для расчета возраста
    DROP TRIGGER IF EXISTS trigger_calculate_age ON tables.patients;
    CREATE TRIGGER trigger_calculate_age
    BEFORE INSERT OR UPDATE ON tables.patients
    FOR EACH ROW
    EXECUTE FUNCTION procedures.calculate_age();

    -- Для обновления статуса записи
    DROP TRIGGER IF EXISTS trigger_update_status ON tables.appointments;
    CREATE TRIGGER trigger_update_status
    BEFORE INSERT OR UPDATE ON tables.appointments
    FOR EACH ROW
    EXECUTE FUNCTION procedures.update_appointment_status();
    
    -- Устанавливаем флаг инициализации в TRUE
    UPDATE init.initialization_status SET is_initialized = TRUE;
    
    RAISE NOTICE 'База данных инициализирована.';
END;
$$;

-- Вызов процедуры инициализации
-- CALL init.initialize_database();

