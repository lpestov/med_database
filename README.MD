# Медицинская база данных для врачей

1. Предметная область: Медицинский сервис для записи пациентов и управления медицинскими данными
2. Функциональные требования
- Управление пациентами: создание, обновление, удаление данных.
- Учет записей на прием: добавление, изменение статусов.
- Ведение медицинской книжки с заключениями врачей.
- Управление списком докторов и их привязкой к поликлиникам.

#### Схема БД:

   (_Соблюдается 3НФ так как отсутствуют дубликаты и составные данные, у каждой записи есть первичный ключ и нет транзитивных зависимостей_)
- **Пациенты**

  **Атрибуты:**

    - `id` (Primary Key)
    - `full_name` (ФИО пациента)
    - `birth_date` (Дата рождения)
    - `age` ( *Возраст/{производный от **birth_date**}* )
    - `contacts` (Контактные данные, например, номер телефона или email)
    - `passport_data` (Паспортные данные)
    - `insurance_policy_number` (Номер полиса ОМС)

  **Почему 3НФ:** Уникальные атрибуты, никаких транзитивных зависимостей (все атрибуты зависят только от `id`).

- **Доктора**

  **Атрибуты:**

    - `id` (Primary Key)
    - `full_name` (ФИО врача)
    - `specialization` (Специализация врача)
    - `contacts` (Контакты врача)
    - `clinic_id` (Foreign Key на таблицу "Поликлиника")

  **Почему 3НФ:** Специализация и контакты связаны только с конкретным доктором.

- **Записи на прием**

  **Атрибуты:**

    - `id` (Primary Key)
    - `patient_id` (Foreign Key на "Пациенты")
    - `doctor_id` (Foreign Key на "Доктора")
    - `appointment_date` (Дата приема)
    - `status` (Статус записи: запланировано, отменено, завершено, пропущено)
    - `clinic_id` (Foreign Key на таблицу "Поликлиника")

  **Почему 3НФ:** Все атрибуты описывают конкретную запись. Поля связаны только через первичный ключ.

- **Медицинская книжка**

  **Атрибуты:**

    - `id` (Primary Key)
    - `patient_id` (Foreign Key на "Пациенты")
    - `conclusion` (Заключение врача)
    - `record_date` (Дата записи)

  **Почему 3НФ:** Заключение и дата относятся только к одной записи в книжке.

- **Поликлиника**

  **Атрибуты:**

    - `id` (Primary Key)
    - `name` (Название поликлиники
    - `address` (Адрес)
    - `phone` (Телефон)

  **Почему 3НФ:** Адрес и телефон относятся только к конкретной поликлинике.

**ER-диаграмма**: ![Example Image](https://i.ibb.co/0MtDmP9/image.png)

## Структура базы данных и функционал

#### 1. Пользователи и база данных

- Создается пользователь **`med_user`** (с ограниченными правами).
- Создается база данных **`med_database`**, которой владеет пользователь **`med_procedures_owner`**.
- `med_procedures_owner` создается после запуска `owner_init.sql`.
- Настраиваются параметры подключения и пути поиска (**search_path**).

---

#### 2. Схемы

- **`schema tables`** – хранит таблицы (`patients`, `doctors`, `clinic`, `appointments`, `medical_records`).
- **`schema procedures`** – хранит процедуры, функции и триггеры для логики приложения.
- **`schema init`** – хранит таблицу и набор функций/процедур для инициализации и состояния проекта.

---

#### 3. Таблицы

| Таблица           | Описание |
|------------------|----------|
| **`patients`** | Данные о пациентах (ФИО, дата рождения, полис, возраст и т. д.). |
| **`clinic`** | Данные о поликлиниках (название, адрес, телефон). |
| **`doctors`** | Данные о докторах (ФИО, специализация, контакты, связь с поликлиникой). |
| **`appointments`** | Записи на прием (пациент, дата, доктор, статус). |
| **`medical_records`** | Медкнижка с записями и заключениями по пациенту. |

---

#### 4. Индексы

- Создается индекс для ускоренного поиска по `full_name` в таблице **`patients`**.

---

#### 5. Функции и триггеры

- **`calculate_age()`** – триггерная функция для автоматического пересчета возраста пациента (`age`) при вставке или обновлении даты рождения.
- **`update_appointment_status()`** – триггерная функция для изменения статуса приема (например, проставление "пропущено", если дата приема уже прошла).
- **`search_by_key()`** – функция поиска в заданной таблице по указанному столбцу. Возвращает результат в формате JSON.
- **`count_tables()`** – подсчитывает количество таблиц в схеме **`tables`**.
- **`get_all_table_headers()`** – возвращает структуру колонок любой таблицы схемы **`tables`** в формате JSON.
- **`get_all_data(table_name)`** – возвращает все данные из указанной таблицы в формате JSON.

---

#### 6. Хранимые процедуры

- **`delete_record(table_name, column_name, key_value)`** – удаляет запись из таблицы по ключу.
- **`insert_into_table(table_name, columns, info)`** – вставляет запись в таблицу динамически, используя массив столбцов и их значений.
- **`update_record(table_name, column_name, new_value, key_column, key_value)`** – обновляет заданную колонку в таблице.
- **`drop_database_schema()`** – удаляет схему **`tables`** и связанные объекты каскадно (доступна только владельцу схемы).
- **`clear_table(table_name)`** – очищает указанную таблицу (`TRUNCATE`).
- **`clear_all_tables()`** – очищает все таблицы схемы **`tables`**.
- **`seed_data()`** – заполняет таблицы демонстрационными данными (`поликлиники`, `доктора`, `пациенты`, `записи на прием`, `медкнижки`).

---

#### 7. Инициализация базы (**schema init**)

- **`initialization_status`** – таблица, которая хранит флаг (`Boolean`), указывающий, инициализирована ли база данных.
- **`is_db_initialized()`** – функция, возвращающая текущее состояние инициализации.
- **`initialize_database()`** – процедура, выполняющая всю необходимую подготовку (создание схем, индексов, триггеров, назначение прав доступа и т. д.).
- Заканчивается установкой флага инициализации в **TRUE**.



## Запуск

1.
    ```sh
    psql -U postgres -f owner_init.sql
    psql -U med_procedures_owner -f med_database.sql
    run main.py
    ```
