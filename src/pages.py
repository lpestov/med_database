import tkinter as tk
from tkinter import messagebox as ms
from tkinter import ttk

from PIL import Image, ImageTk

from db_manager import DataBaseManager
from tab import Tab


class MainPage(tk.Frame):
    def __init__(self, master):
        super().__init__(master)
        self.database_manager = DataBaseManager("med_user")

        self.menu_bar = tk.Menu(self)
        self.db_menu = tk.Menu(self.menu_bar, tearoff=0)
        self.db_menu.add_command(label="Seed database", command=self.seed_database)
        self.db_menu.add_command(
            label="Clear all tables", command=self.clear_all_tables
        )
        self.db_menu.add_command(
            label="Exit to Welcome Page", command=self.exit_to_welcome_page
        )
        self.menu_bar.add_cascade(label="Menu", menu=self.db_menu)
        self.master.config(menu=self.menu_bar)

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

    def seed_database(self):
        try:
            self.database_manager.seed_data()
            ms.showinfo(title="Success", message="Database seeded successully")
            self.update_all_tables()
        except Exception as e:
            ms.showerror(title="Seeding Error", message="Seed database error")
            print(e)

    def clear_all_tables(self):
        try:
            self.database_manager.clear_all_tables()
            ms.showinfo(title="Success", message="All tables cleared successully")
            self.update_all_tables()
        except Exception as e:
            ms.showerror(title="Clearing Error", message="Clear database error")
            print(e)

    def exit_to_welcome_page(self):
        self.menu_bar.destroy()
        self.db_menu.destroy()
        self.forget()
        self.master.config(menu=None)
        welcome_page = WelcomePage(self.master)
        welcome_page.pack(expand=True, fill="both")

    def dummy_action(self):
        print("Clicked!")


class WelcomePage(tk.Frame):
    def __init__(self, master):
        super().__init__(master, background="white")

        self.db_manager = DataBaseManager("med_procedures_owner")

        # Загрузка изображения
        image = Image.open("images/left.jpg")
        image = image.resize((250, 250))  # Подгонка размера
        self.left_img = ImageTk.PhotoImage(image)

        # Установка изображения через Label
        left_img_label = tk.Label(self, image=self.left_img)
        left_img_label.pack(side="left", padx=50)

        # Загрузка изображения
        image = Image.open("images/right.jpg")
        image = image.resize((250, 250))  # Подгонка размера
        self.right_img = ImageTk.PhotoImage(image)

        # Установка изображения через Label
        right_img_label = tk.Label(self, image=self.right_img)
        right_img_label.pack(side="right", padx=50)

        welcome_lb = tk.Label(
            self,
            text="Welcome to MedDataBase!",
            font=("Arial", 24, "bold"),
            background="white",
            foreground="black",
        )
        welcome_lb.pack(pady=(50, 20), expand=True)

        button_frame = tk.Frame(self, background="white")
        button_frame.pack(anchor=tk.CENTER, pady=(0, 100))

        init_db_btn = tk.Button(
            button_frame,
            text="Init Database",
            font=("Arial", 14),
            command=self.init_database,
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
            command=self.drop_database,
        )
        drop_db_btn.pack(side=tk.LEFT, padx=5)

    def drop_database(self):
        if not self.db_manager.is_database_initialized():
            ms.showerror(title="DROP", message="Database is already dropped")
            return

        try:
            self.db_manager.drop_database()
            ms.showinfo(title="Success", message="Database deleted successfully")
        except Exception as e:
            ms.showerror(title="DROP ERROR", message="database drop error")
            print(e)

    def init_database(self):
        if self.db_manager.is_database_initialized():
            ms.showerror(title="INIT", message="Database is already initialized")
            return

        try:
            self.db_manager.init_db_for_med_user()
            ms.showinfo(title="Success", message="Database initialized successfully")
        except Exception as e:
            ms.showerror(title="INIT ERROR", message="database init error")
            print(e)

    def start_main_page(self):
        if not self.db_manager.is_database_initialized():
            ms.showerror(title="Start Error", message="Database is not initialized")
            return

        del self.db_manager
        self.forget()
        main_page = MainPage(self.master)
        main_page.pack(expand=True, fill="both")

    def dummy_action(self):
        print("Clicked")
