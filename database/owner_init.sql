-- Создаем пользователя-владельца процедур и БД
CREATE USER med_procedures_owner WITH PASSWORD 'super';
CREATE DATABASE med_procedures_owner OWNER med_procedures_owner;
ALTER USER med_procedures_owner WITH CREATEDB CREATEROLE;

-- Проверяем, существует ли пользователь med_user
DO $$
BEGIN
  IF role_exists('med_user') THEN
    -- Назначаем med_procedures_owner администратором для med_user
    GRANT med_user TO med_procedures_owner WITH ADMIN OPTION;
    RAISE NOTICE 'med_procedures_owner назначен администратором для med_user';
  ELSE
    RAISE NOTICE 'Пользователь med_user не существует, пропускаем назначение администратора';
  END IF;
END $$;

