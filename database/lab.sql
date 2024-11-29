-- Создаем пользователя с ограниченными правами для использования (до этого работает от postgres)
CREATE USER med_user WITH PASSWORD 'secure_password';

-- Создаем базу данных
CREATE DATABASE med_database OWNER med_user;

-- Подключаемся к базе данных
\c med_database

-- Ограничиваем привилегии для med_user и для новых юзеров
REVOKE ALL ON DATABASE med_database FROM PUBLIC;
GRANT CONNECT ON DATABASE med_database TO med_user;


-- Таблица "Пациенты"
CREATE TABLE patients (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    birth_date DATE NOT NULL,
    contacts VARCHAR(255),
    passport_data VARCHAR(50) NOT NULL,
    insurance_policy_number VARCHAR(50) NOT NULL
);

-- Таблица "Поликлиника"
CREATE TABLE clinic (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL
);

-- Таблица "Доктора"
CREATE TABLE doctors (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    specialization VARCHAR(100) NOT NULL,
    contacts VARCHAR(255),
    clinic_id INT NOT NULL REFERENCES clinic(id) ON DELETE CASCADE
);

-- Таблица "Записи на прием"
CREATE TABLE appointments (
    id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(id) ON DELETE CASCADE,
    doctor_id INT REFERENCES doctors(id) ON DELETE CASCADE,
    appointment_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'запланировано',
    clinic_id INT REFERENCES clinic(id) ON DELETE CASCADE,
    CONSTRAINT chk_status CHECK (status IN ('запланировано', 'пропущено', 'отменено', 'завершено'))
);

-- Таблица "Медицинская книжка"
CREATE TABLE medical_records (
    id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(id) ON DELETE CASCADE,
    conclusion TEXT NOT NULL,
    record_date DATE NOT NULL
);

-- Для ускорения поиска по имени пациента создаем индекс:
CREATE INDEX idx_patients_full_name ON patients(full_name);

-- Добавляем поле age (возраст) как производное
ALTER TABLE patients ADD COLUMN age INT;

CREATE OR REPLACE FUNCTION calculate_age()
RETURNS TRIGGER AS $$
BEGIN
    NEW.age := DATE_PART('year', AGE(NEW.birth_date));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calculate_age
BEFORE INSERT OR UPDATE ON patients
FOR EACH ROW
EXECUTE FUNCTION calculate_age();

-- Триггер для изменения статуса записи
CREATE OR REPLACE FUNCTION update_appointment_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.appointment_date < CURRENT_DATE AND NEW.status = 'запланировано' THEN
        NEW.status := 'пропущено';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_status
BEFORE INSERT OR UPDATE ON appointments
FOR EACH ROW
EXECUTE FUNCTION update_appointment_status();

-- Даем пользователю med_user доступ только к чтению и записи данных
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO med_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO med_user;

