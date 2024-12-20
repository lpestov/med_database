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

-- Назначаем med_procedures_owner права на таблицы, функции и процедуры
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
SECURITY DEFINER -- процедура выполняется с правами владельца
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
SECURITY DEFINER
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
SECURITY DEFINER
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
SECURITY DEFINER
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format('DELETE FROM tables.%I WHERE %I = %L', table_name, column_name, key_value);
END;
$$;
-- Пример: CALL procedures.delete_record('patients', 'id', '1');

-- Процедура вставки данных
CREATE OR REPLACE PROCEDURE procedures.insert_into_table(table_name TEXT, columns TEXT[], info TEXT[])
SECURITY DEFINER
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
SELECT procedures.insert_into_table(
    'patients',
    ARRAY['full_name', 'birth_date', 'contacts', 'passport_data', 'insurance_policy_number'],
    ARRAY['Иван Иванов', '1980-01-01', '89991234567', '1234 567890', '12345678']
);
*/

-- Процедура изменения записи
CREATE OR REPLACE PROCEDURE procedures.update_record(table_name TEXT, column_name TEXT, new_value TEXT, key_column TEXT, key_value TEXT)
SECURITY DEFINER
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format('UPDATE tables.%I SET %I = %L WHERE %I = %L',
                   table_name, column_name, new_value, key_column, key_value);
END;
$$;
-- Пример: CALL procedures.update_record('patients', 'contacts', '89991112233', 'id', '1');

-- Процедура для удаления схемы с каскадным удалением всех таблиц
CREATE OR REPLACE PROCEDURE procedures.drop_database_schema()
SECURITY DEFINER 
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE 'DROP SCHEMA IF EXISTS tables CASCADE';
    RAISE NOTICE 'Схема tables и все связанные таблицы удалены.';
END;
$$;
-- Пример: CALL procedures.drop_database_schema();

-- Функция для подсчета таблиц
CREATE OR REPLACE FUNCTION procedures.count_tables()
RETURNS INTEGER AS $$
DECLARE
    table_count INTEGER;
SECURITY DEFINER
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
SECURITY DEFINER
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
SECURITY DEFINER
BEGIN
    RETURN QUERY EXECUTE format('SELECT row_to_json(t) FROM tables.%I AS t', table_name);
END;
$$ LANGUAGE plpgsql;
-- Пример: SELECT * FROM procedures.get_all_data('patients');

-- Процедура для заполнения данными
CREATE OR REPLACE PROCEDURE procedures.seed_data()
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
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

-- Создаем процедуру инициализации в схеме init
SET search_path TO init, tables, procedures, public;

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
ALTER PROCEDURE procedures.seed_data() OWNER TO med_procedures_owner;

CREATE OR REPLACE PROCEDURE init.initialize_database()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Даем пользователю права на схему с таблицами
    GRANT USAGE ON SCHEMA tables TO med_user;
    -- Даем права на таблицы
    GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA tables TO med_user;

    -- Даем права на последовательности
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA tables TO med_user;

    -- Даем пользователю права на схему procedures (пока что только на использование, все остальное на уровне конкретных процедур)
    GRANT USAGE ON SCHEMA procedures TO med_user;
    
    -- Даем права на отдельные процедуры
    GRANT EXECUTE ON PROCEDURE procedures.delete_record(TEXT, TEXT, TEXT) TO med_user;
    GRANT EXECUTE ON PROCEDURE procedures.insert_into_table(TEXT, TEXT[], TEXT[]) TO med_user;
    GRANT EXECUTE ON PROCEDURE procedures.update_record(TEXT, TEXT, TEXT, TEXT, TEXT) TO med_user;
    GRANT EXECUTE ON FUNCTION procedures.search_by_key(TEXT, TEXT, TEXT) TO med_user;
    GRANT EXECUTE ON FUNCTION procedures.count_tables() TO med_user;
    GRANT EXECUTE ON FUNCTION procedures.get_all_table_headers() TO med_user;
    GRANT EXECUTE ON FUNCTION procedures.get_all_data(TEXT) TO med_user;
    -- GRANT EXECUTE ON PROCEDURE procedures.drop_database_schema() TO med_user; лучше не надо давать такое право
    -- GRANT EXECUTE ON PROCEDURE procedures.seed_data() TO med_user; наверно тоже не стоит, заполним один раз
    
    -- Заполнение данными
    CALL procedures.seed_data();
    
    RAISE NOTICE 'База данных инициализирована.';
END;
$$;

-- Вызов процедуры инициализации
-- CALL init.initialize_database();

