-- Заполняем таблицу "Поликлиника"
INSERT INTO med_schema.clinic (name, address, phone) VALUES
    ('Поликлиника №1', 'г. Нижний Новгород, ул. Ленина, д. 1', '8311234567'),
    ('Поликлиника №2', 'г. Нижний Новгород, ул. Белинского, д. 10', '8312345678'),
    ('Поликлиника №3', 'г. Нижний Новгород, ул. Горького, д. 15', '8313456789');

-- Заполняем таблицу "Доктора"
INSERT INTO med_schema.doctors (full_name, specialization, contacts, clinic_id) VALUES
    ('Иванов Иван Иванович', 'Терапевт', '89101234567', 1),
    ('Петров Петр Петрович', 'Хирург', '89109876543', 2),
    ('Сидоров Сидор Сидорович', 'Кардиолог', '89201234567', 3);

-- Заполняем таблицу "Пациенты"
INSERT INTO med_schema.patients (full_name, birth_date, contacts, passport_data, insurance_policy_number) VALUES
    ('Алексеева Анна Сергеевна', '1985-05-12', '89031234567', '1234 567890', '12345678'),
    ('Михайлов Михаил Андреевич', '1990-02-28', '89041234567', '2345 678901', '23456789'),
    ('Васильева Василиса Ивановна', '2000-10-15', '89051234567', '3456 789012', '34567890');

-- Заполняем таблицу "Записи на прием"
INSERT INTO med_schema.appointments (patient_id, doctor_id, appointment_date, status, clinic_id) VALUES
    (1, 1, '2024-12-01', 'запланировано', 1),
    (2, 2, '2024-11-15', 'запланировано', 2),
    (3, 3, '2024-11-10', 'запланировано', 3);

-- Заполняем таблицу "Медицинская книжка"
INSERT INTO med_schema.medical_records (patient_id, conclusion, record_date) VALUES
    (1, 'Общее состояние хорошее. Рекомендовано продолжить лечение.', '2024-11-01'),
    (2, 'Необходима операция на коленном суставе.', '2024-11-10'),
    (3, 'Проведена успешная терапия. Пациентка в стабильном состоянии.', '2024-11-05');
