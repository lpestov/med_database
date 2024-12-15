from configparser import ConfigParser

from sqlalchemy import create_engine, text


class DataBaseManager:
    def __init__(self):
        self.connection_params = self.__get_config()
        self.engine = create_engine(
            "postgresql+psycopg2://{}:{}@{}/{}".format(
                self.connection_params["user"],
                self.connection_params["password"],
                self.connection_params["host"],
                self.connection_params["database"],
            ),
            echo=True,
            isolation_level="SERIALIZABLE",
        )

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
        query = "SELECT * FROM count_tables();"
        with self.engine.connect() as connect:
            tables_num = connect.execute(text(query)).fetchall()[0][0]
            connect.commit()
        return tables_num

    def get_table_titles_and_headers(self):
        """
        Возвращает словарь в формате "название_таблицы": ["заголовок1", "заголовок2", ...]
        """
        query = "SELECT * FROM get_all_table_headers();"
        tables_info = None
        with self.engine.connect() as connect:
            tables_info = connect.execute(text(query)).fetchall()[0][0]
            connect.commit()
        return tables_info

    def get_data_from_table(self, table_title):
        query = "SELECT * FROM get_all_data('{}')".format(table_title)
        with self.engine.connect() as connect:
            tables_info = [row[0] for row in connect.execute(text(query)).fetchall()]
            connect.commit()
        return tables_info