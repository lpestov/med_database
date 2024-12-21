import tkinter as tk
from tkinter import ttk

from db_manager import DataBaseManager
from tab import Tab


class MainPage(tk.Frame):
    def __init__(self, master):
        super().__init__(master)
        self.database_manager = DataBaseManager()

        menu_bar = tk.Menu(self)
        db_menu = tk.Menu(menu_bar, tearoff=0)
        db_menu.add_command(label="Создать базу данных", command=self.dummy_action)
        db_menu.add_command(label="Удалить базу данных", command=self.dummy_action)
        menu_bar.add_cascade(label="База данных", menu=db_menu)
        self.master.config(menu=menu_bar)

        tables_info = self.database_manager.get_table_titles_and_headers()

        # Notebook для вкладок
        self.notebook = ttk.Notebook(self)
        self.notebook.pack(fill="both", expand=True)
        self.tabs = []

        # Подключение вкладок. В каждой вкладке таблица из БД и кнопки для манипуляции данными
        for table_title in tables_info:
            table_data = self.database_manager.get_data_from_table(table_title)
            new_tab = Tab(
                self.notebook,
                self,
                table_title,
                tables_info[table_title],
                table_data,
                self.database_manager,
            )
            self.notebook.add(new_tab, text=table_title)

    def update_all_tables(self):
        for tab_id in self.notebook.tabs():
            tab = self.notebook.nametowidget(tab_id)
            tab.update_displayed_table_data()

    def dummy_action(self):
        print("Clicked!")


class WelcomePage(tk.Frame):
    def __init__(self, master):
        super().__init__(master)

        welcome_lb = tk.Label(
            self, text="Welcome to MedDataBase", font=("Arial", 24, "bold")
        )
        welcome_lb.pack(pady=(50, 20), expand=True)

        button_frame = tk.Frame(self)
        button_frame.pack(anchor=tk.CENTER, pady=(0, 100))

        init_db_btn = tk.Button(
            button_frame,
            text="Init Database",
            font=("Arial", 14),
            command=self.dummy_action,
        )
        init_db_btn.pack(side=tk.LEFT, padx=5)

        start_btn = tk.Button(
            button_frame,
            text="Get started",
            font=("Arial", 14),
            command=self.start_main_page,
        )
        start_btn.pack(side=tk.LEFT, padx=5)

        drop_db_btn = tk.Button(
            button_frame,
            text="Drop Database",
            font=("Arial", 14),
            command=self.dummy_action,
        )
        drop_db_btn.pack(side=tk.LEFT, padx=5)

    def start_main_page(self):
        self.forget()
        main_page = MainPage(self.master)
        main_page.pack(expand=True, fill="both")

    def dummy_action(self):
        print("Clicked")
