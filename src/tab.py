import tkinter as tk
from tkinter import font as tkfont
from tkinter import ttk


class Tab(ttk.Frame):
    def __init__(self, master, table_columns, table_data):
        super().__init__(master)
        self.setup_ui(table_columns, table_data)

    def setup_ui(self, table_columns, table_data):
        # Таблица
        self.tree = ttk.Treeview(self, columns=table_columns, show="headings")
        for table_column in table_columns:
            self.tree.heading(table_column, text=table_column.upper())
            self.tree.column(table_column, anchor="center")

        for row in table_data:
            self.tree.insert("", "end", values=row)
        self.tree.pack(fill="both", expand=True, padx=5, pady=5)
        self.autosize_table_columns(table_columns, table_data)

        # Панель с кнопками
        buttons_frame = tk.Frame(self)
        buttons_frame.pack(fill="x", padx=5, pady=5)

        # Кнопки
        add_button = tk.Button(buttons_frame, text="Add", command=self.dummy_action)
        edit_button = tk.Button(buttons_frame, text="Edit", command=self.dummy_action)
        delete_button = tk.Button(
            buttons_frame, text="Delete", command=self.dummy_action
        )
        find_button = tk.Button(buttons_frame, text="Find", command=self.dummy_action)

        add_button.pack(side="left", padx=5)
        edit_button.pack(side="left", padx=5)
        delete_button.pack(side="left", padx=5)
        find_button.pack(side="left", padx=5)

    def autosize_table_columns(self, columns, data):
        style = ttk.Style()
        tree_style = style.lookup("Treeview", "font")  # Шрифт используемый в Treeview
        tree_font = tkfont.Font(name=tree_style, exists=True)
        padding = 10  # Добавочный отступ для эстетики

        for col_index, col in enumerate(columns):
            # Получение максимальной ширины заголовка
            max_width = tree_font.measure(col.upper())

            # Получение максимальной ширины содержимого столбца
            for row in data:
                cell_value = str(row[col_index])  # Конвертация значения в строку
                cell_width = tree_font.measure(cell_value)
                max_width = max(max_width, cell_width)

            # Установка ширины столбца
            self.tree.column(col, width=max_width + padding)

    def dummy_action(self):
        print("Button clicked!")
