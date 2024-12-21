-- Создаем пользователя-владельца процедур и БД
CREATE USER med_procedures_owner WITH PASSWORD 'super';
CREATE DATABASE med_procedures_owner OWNER med_procedures_owner;
ALTER USER med_procedures_owner WITH CREATEDB CREATEROLE;

-- Создаем пользователя с ограниченными правами для использования
CREATE USER med_user WITH PASSWORD 'qwerty';

-- Назначаем med_procedures_owner администратором для med_user
GRANT med_user TO med_procedures_owner WITH ADMIN OPTION;
