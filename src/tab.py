import tkinter as tk
from tkinter import font as tkfont
from tkinter import ttk


class Tab(ttk.Frame):
    def __init__(self, master, table_name, table_columns, table_data, db_manager):
        super().__init__(master)
        self.table_name = table_name
        self.table_columns = table_columns
        self.table_data = table_data
        self.db_manager = db_manager
        self.setup_ui()

    def setup_ui(self):
        # Таблица
        self.tree = ttk.Treeview(self, columns=self.table_columns, show="headings")
        for table_column in self.table_columns:
            self.tree.heading(table_column, text=table_column.upper())
            self.tree.column(table_column, anchor="center")

        self.display_table_data()

        # Панель с кнопками
        buttons_frame = tk.Frame(self)
        buttons_frame.pack(fill="x", padx=5, pady=5)

        # Кнопки
        add_button = tk.Button(buttons_frame, text="Add", command=self.add_table_data)
        edit_button = tk.Button(buttons_frame, text="Edit", command=self.dummy_action)
        delete_button = tk.Button(
            buttons_frame, text="Delete", command=self.dummy_action
        )
        find_button = tk.Button(buttons_frame, text="Find", command=self.dummy_action)

        add_button.pack(side="left", padx=5)
        edit_button.pack(side="left", padx=5)
        delete_button.pack(side="left", padx=5)
        find_button.pack(side="left", padx=5)

    def autosize_table_columns(self):
        style = ttk.Style()
        tree_style = style.lookup("Treeview", "font")  # Шрифт используемый в Treeview
        tree_font = tkfont.Font(name=tree_style, exists=True)
        padding = 10  # Добавочный отступ для эстетики

        for col_index, col in enumerate(self.table_columns):
            # Получение максимальной ширины заголовка
            max_width = tree_font.measure(col.upper())

            # Получение максимальной ширины содержимого столбца
            for row in self.table_data:
                cell_value = str(row[col])  # Конвертация значения в строку
                cell_width = tree_font.measure(cell_value)
                max_width = max(max_width, cell_width)

            # Установка ширины столбца
            self.tree.column(col, width=max_width + padding)

    def display_table_data(self):
        for row in self.table_data:
            data = [row[key] for key in row.keys()]
            self.tree.insert("", "end", values=data)
        self.tree.pack(fill="both", expand=True, padx=5, pady=5)
        self.autosize_table_columns()

    # TODO: убрать ввод ID (должен сам вычисляться в БД)
    def add_table_data(self):
        input_table_win = tk.Toplevel(self)
        input_table_win.title("New Input Data")

        entries = {}

        table_headers_without_id_col = list(
            filter(lambda x: x != "id", self.table_columns)
        )

        # Создание заголовков таблицы для ввода и полей для ввода
        for col_idx, col in enumerate(table_headers_without_id_col):
            input_table_header = tk.Label(input_table_win, text=col)
            input_table_header.grid(row=0, column=col_idx, padx=5, pady=5)

            entry = tk.Entry(input_table_win, width=15, justify="center")

            entries[col] = entry
            entry.grid(row=1, column=col_idx, padx=5, pady=6)

        save_button = tk.Button(
            input_table_win,
            text="Save",
            command=lambda: self.db_manager.add_data(
                self.table_name,
                table_headers_without_id_col,
                [e.get() for e in entries.values()],
            ),
        )
        save_button.grid(row=2, column=0, columnspan=len(self.table_columns), pady=10)

    def dummy_action(self):
        print("Button clicked!")
