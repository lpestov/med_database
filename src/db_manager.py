from configparser import ConfigParser

import psycopg2


class DataBaseManager:
    def __init__(self):
        connection_params = self.__get_config()
        self.connection = psycopg2.connect(**connection_params)

        self.cursor = self.connection.cursor()

    def __get_config(self, filename="database.ini", section="postgresql"):
        # create a parser
        parser = ConfigParser()

        # read config file
        parser.read(filename)

        # get section, default to postgresql
        db_connection_info = {}
        if parser.has_section(section):
            params = parser.items(section)
            for param in params:
                db_connection_info[param[0]] = param[1]
        else:
            raise Exception(
                "Section {0} not found in the {1} file".format(section, filename)
            )

        return db_connection_info

    def get_tables_number(self):
        table_count_query = """
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'med_schema';
            """
        self.cursor.execute(table_count_query)
        table_count = self.cursor.fetchone()[0]
        return table_count

    def get_table_titles_and_headings(self):
        """
        Возвращает словарь в формате "название_таблицы": ["заголовок1", "заголовок2", ...]
        """
        table_headings_query = """
            SELECT table_name, column_name
            FROM information_schema.columns
            WHERE table_schema = 'med_schema'
            ORDER BY table_name, ordinal_position;
            """
        self.cursor.execute(table_headings_query)
        columns = self.cursor.fetchall()

        # Группируем столбцы по таблицам
        table_headings = {}
        for table_name, column_name in columns:
            if table_name not in table_headings:
                table_headings[table_name] = []
            table_headings[table_name].append(column_name)
        return table_headings

    def get_data_from_table(self, table_title):
        self.cursor.execute(f"SELECT * FROM {table_title};")
        rows = self.cursor.fetchall()
        return rows

    def disconnect(self):
        self.cursor.close()
        self.connection.close()
