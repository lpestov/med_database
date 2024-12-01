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

        tables_info = self.database_manager.get_table_titles_and_headings()

        # Notebook для вкладок
        notebook = ttk.Notebook(self)
        notebook.pack(fill="both", expand=True)
        self.tabs = []

        # Подключение вкладок. В каждой вкладке таблица из БД и кнопки для манипуляции данными
        for table_title in tables_info:
            table_data = self.database_manager.get_data_from_table(table_title)
            new_tab = Tab(notebook, tables_info[table_title], table_data)
            notebook.add(new_tab, text=table_title)

    def dummy_action(self):
        print("Clicked!")


class WelcomePage(tk.Frame):
    def __init__(self, master):
        super().__init__(master)

        welcome_lb = tk.Label(
            self, text="Welcome to MedDataBase", font=("Arial", 24, "bold")
        )
        welcome_lb.pack(pady=(50, 20), expand=True)

        start_btn = tk.Button(
            self, text="Get started", font=("Arial", 14), command=self.start_main_page
        )

        start_btn.pack(pady=(0, 100))

    def start_main_page(self):
        self.forget()
        main_page = MainPage(self.master)
        main_page.pack(expand=True, fill="both")
