SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE med_database;

DROP ROLE med_user;

-- Создаем пользователя с ограниченными правами для использования (до этого работает от postgres)
CREATE USER med_user WITH PASSWORD 'secure_password';

-- Создаем базу данных
CREATE DATABASE med_database OWNER med_user;

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

-- Ограничиваем привилегии для med_user и для новых юзеров
REVOKE ALL ON DATABASE med_database FROM PUBLIC;
GRANT CONNECT ON DATABASE med_database TO med_user;

-- Создаем схему
CREATE SCHEMA med_schema AUTHORIZATION med_user;

-- Добавляем в search_path
SET search_path TO med_schema;

-- Установим search_path на уровне базы данных
ALTER DATABASE med_database SET search_path TO med_schema, public;

-- Таблица "Пациенты"
CREATE TABLE med_schema.patients (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    birth_date DATE NOT NULL,
    contacts VARCHAR(255),
    passport_data VARCHAR(50) NOT NULL,
    insurance_policy_number VARCHAR(50) NOT NULL
);

-- Таблица "Поликлиника"
CREATE TABLE med_schema.clinic (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL
);

-- Таблица "Доктора"
CREATE TABLE med_schema.doctors (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    specialization VARCHAR(100) NOT NULL,
    contacts VARCHAR(255),
    clinic_id INT NOT NULL REFERENCES med_schema.clinic(id) ON DELETE CASCADE
);

-- Таблица "Записи на прием"
CREATE TABLE med_schema.appointments (
    id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES med_schema.patients(id) ON DELETE CASCADE,
    doctor_id INT REFERENCES med_schema.doctors(id) ON DELETE CASCADE,
    appointment_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'запланировано',
    clinic_id INT REFERENCES med_schema.clinic(id) ON DELETE CASCADE,
    CONSTRAINT chk_status CHECK (status IN ('запланировано', 'пропущено', 'отменено', 'завершено'))
);

-- Таблица "Медицинская книжка"
CREATE TABLE med_schema.medical_records (
    id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES med_schema.patients(id) ON DELETE CASCADE,
    conclusion TEXT NOT NULL,
    record_date DATE NOT NULL
);

-- Для ускорения поиска по имени пациента создаем индекс:
CREATE INDEX idx_patients_full_name ON med_schema.patients(full_name);

-- Добавляем поле age (возраст) как производное
ALTER TABLE med_schema.patients ADD COLUMN age INT;

CREATE OR REPLACE FUNCTION med_schema.calculate_age()
RETURNS TRIGGER AS $$
BEGIN
    NEW.age := DATE_PART('year', AGE(NEW.birth_date));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calculate_age
BEFORE INSERT OR UPDATE ON med_schema.patients
FOR EACH ROW
EXECUTE FUNCTION med_schema.calculate_age();

-- Триггер для изменения статуса записи
CREATE OR REPLACE FUNCTION med_schema.update_appointment_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.appointment_date < CURRENT_DATE AND NEW.status = 'запланировано' THEN
        NEW.status := 'пропущено';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_status
BEFORE INSERT OR UPDATE ON med_schema.appointments
FOR EACH ROW
EXECUTE FUNCTION med_schema.update_appointment_status();

-- Даем пользователю med_user доступ только к чтению и записи данных в схеме
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA med_schema TO med_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA med_schema TO med_user;


-- Функции для доступа через gui

-- Процедура поиска записи по ключу
CREATE OR REPLACE FUNCTION search_by_key(
    table_name TEXT,
    column_name TEXT,
    search_value TEXT
)
RETURNS SETOF RECORD AS $$
BEGIN
    RETURN QUERY EXECUTE FORMAT(
        'SELECT * FROM %I WHERE %I = %L',
        table_name,
        column_name,
        search_value
    );
END;
$$ LANGUAGE plpgsql;

/* Пример:
SELECT * FROM search_by_key('patients', 'full_name', 'Иван Иванов') AS t(
    id INTEGER,
    full_name VARCHAR,
    birth_date DATE,
    contacts VARCHAR,
    passport_data VARCHAR,
    insurance_policy_number VARCHAR
);
*/

-- Процедура удаления записи
CREATE OR REPLACE PROCEDURE delete_record(table_name TEXT, column_name TEXT, key_value TEXT)
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format('DELETE FROM %I WHERE %I = %L', table_name, column_name, key_value);
END;
$$;
-- Пример: CALL delete_record('patients', 'id', '1');

-- Процедура вставки данных
CREATE OR REPLACE FUNCTION insert_into_table(table_name TEXT, columns TEXT[], info TEXT[])
RETURNS VOID AS $$
BEGIN
    EXECUTE format('INSERT INTO %I (%s) VALUES (%s)',
                   table_name,
                   array_to_string(columns, ', '),
                   array_to_string(info, ', '));
END;
$$ LANGUAGE plpgsql;

/* Пример: 
SELECT insert_into_table(
    'patients',
    ARRAY['full_name', 'birth_date', 'contacts', 'passport_data', 'insurance_policy_number'],
    ARRAY['\'Иван Иванов\'', '\'1980-01-01\'', '\'89991234567\'', '\'1234 567890\'', '\'12345678901234\'']
);
*/

-- Процедура изменения записи 
CREATE OR REPLACE PROCEDURE update_record(table_name TEXT, column_name TEXT, new_value TEXT, key_column TEXT, key_value TEXT)
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format('UPDATE %I SET %I = %L WHERE %I = %L',
                   table_name, column_name, new_value, key_column, key_value);
END;
$$;
-- Пример: CALL update_record('patients', 'contacts', '89991112233', 'id', '1');


-- Функция для подсчета таблиц
CREATE OR REPLACE FUNCTION count_tables()
RETURNS INTEGER AS $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'med_schema';

    RETURN table_count;
END;
$$ LANGUAGE plpgsql;
-- Пример: SELECT count_tables();

-- Функция для получения заголовков таблицы
CREATE OR REPLACE FUNCTION get_table_headers(table_name TEXT)
RETURNS TABLE(column_name TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'med_schema' AND table_name = table_name;
END;
$$ LANGUAGE plpgsql;
-- Пример: SELECT * FROM get_table_headers('patients');

-- Функция для выдачи всех данных из таблицы
CREATE OR REPLACE FUNCTION get_all_data(table_name TEXT)
RETURNS TABLE(result RECORD) AS $$
BEGIN
    RETURN QUERY EXECUTE format('SELECT * FROM %I', table_name);
END;
$$ LANGUAGE plpgsql;
-- Пример: SELECT * FROM get_all_data('patients');











