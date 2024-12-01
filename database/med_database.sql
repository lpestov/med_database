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
