# Список потенциально опасных SQL-команд и ключевых слов
sql_keywords = [
    "SELECT",
    "INSERT",
    "UPDATE",
    "DELETE",
    "DROP",
    "CREATE",
    "ALTER",
    "EXEC",
    "UNION",
    "ALL",
    "ANY",
    "AND",
    "OR",
    "WHERE",
    "LIKE",
    "IN",
    "EXISTS",
    "NOT",
    "FROM",
    "JOIN",
    "OUTER",
    "INNER",
    "ORDER",
    "BY",
    "GROUP",
    "HAVING",
    ";",
    "/*",
    "*/",
    "@@",
    "@",
    "CHAR",
    "NCHAR",
    "VARCHAR",
    "NVARCHAR",
    "CAST",
    "CONVERT",
    "WAITFOR",
    "SLEEP",
    "xp_cmdshell",
    "sp_executesql",
    "sysobjects",
    "syscolumns",
    "INFORMATION_SCHEMA",
    "DATABASE",
    "TABLE",
    "COLUMN",
    "VALUES",
    "TRUNCATE",
    "GRANT",
    "REVOKE",
    "BACKUP",
    "RESTORE",
]


def is_possible_sql_injection(usr_input):
    lower_input = [inp.lower() for inp in usr_input.split()]
    for keyword in sql_keywords:
        if keyword.lower() in lower_input:
            return True  # Найдена потенциальная угроза
    return False
