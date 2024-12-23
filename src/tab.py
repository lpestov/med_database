import tkinter as tk
import tkinter.messagebox as ms
from tkinter import font as tkfont
from tkinter import ttk


class Tab(ttk.Frame):
    def __init__(
        self, master, notebook, table_name, table_columns, table_data, db_manager
    ):
        super().__init__(master)
        self.notebook = notebook
        self.table_name = table_name
        self.table_columns = table_columns
        self.table_data = table_data
        self.db_manager = db_manager
        self.currentHighlightedRecordID = -1
        self.found_records = []
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
        edit_button = tk.Button(
            buttons_frame, text="Edit", command=self.edit_table_cortege
        )
        delete_button = tk.Button(
            buttons_frame, text="Delete", command=self.delete_record
        )
        find_button = tk.Button(
            buttons_frame, text="Find", command=self.find_cortege_window
        )
        clear_table_button = tk.Button(
            buttons_frame, text="Clear Table", command=self.clear_table
        )

        add_button.pack(side="left", padx=5)
        edit_button.pack(side="left", padx=5)
        delete_button.pack(side="left", padx=5)
        find_button.pack(side="left", padx=5)
        clear_table_button.pack(side="left", padx=5)

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

    def update_displayed_table_data(self):
        # Очистка Treeview
        for item in self.tree.get_children():
            self.tree.delete(item)

        # Обновление данных
        self.table_data = self.db_manager.get_data_from_table(self.table_name)
        self.display_table_data()

    def add_table_data(self):
        input_table_win = tk.Toplevel(self)
        input_table_win.title("New Input Data")

        entries = {}

        table_headers_without_id_col_and_age = list(
            filter(lambda x: x != "id" and x != "age", self.table_columns)
        )

        # Создание заголовков таблицы для ввода и полей для ввода
        for col_idx, col in enumerate(table_headers_without_id_col_and_age):
            if col == "status":
                options = ["запланировано", "пропущено", "отменено", "завершено"]
                selected_option = tk.StringVar(value=options[0])
                status_option_menu = tk.OptionMenu(
                    input_table_win, selected_option, *options
                )
                entries[col] = selected_option
                status_option_menu.grid(row=1, column=col_idx, padx=5, pady=6)
                input_table_header = tk.Label(input_table_win, text=col)
                input_table_header.grid(row=0, column=col_idx, padx=5, pady=5)
                continue

            input_table_header = tk.Label(input_table_win, text=col)
            input_table_header.grid(row=0, column=col_idx, padx=5, pady=5)

            entry = tk.Entry(input_table_win, width=15, justify="center")

            entries[col] = entry
            entry.grid(row=1, column=col_idx, padx=5, pady=6)

        save_button = tk.Button(
            input_table_win,
            text="Save",
            command=lambda: self.save_added_table_data(
                table_headers_without_id_col_and_age, entries
            ),
        )
        save_button.grid(row=2, column=0, columnspan=len(self.table_columns), pady=10)

    def save_added_table_data(self, headers, entries):
        try:
            self.db_manager.add_data(
                self.table_name, headers, [e.get() for e in entries.values()]
            )
            ms.showinfo(title="Saved", message="Data saved successfully")
            self.update_displayed_table_data()
        except Exception as e:
            ms.showerror(title="Saving data error", message="Check input data")
            print(e)

    def edit_table_cortege(self):

        selected_cortege = self.tree.selection()

        if not selected_cortege:
            ms.showerror(title="Error", message="No selected cortege")
            return

        selected_cortege = self.tree.item(selected_cortege[0], "values")

        input_table_win = tk.Toplevel(self)
        input_table_win.title("Edit Data")

        entries = {}
        default_entries_vals = {}
        table_headers_without_id_col = list(
            filter(lambda x: x != "id", self.table_columns)
        )

        # Создание заголовков таблицы для ввода и полей для ввода
        for col_idx, col in enumerate(table_headers_without_id_col):
            if col == "age":
                continue

            input_table_header = tk.Label(input_table_win, text=col)
            input_table_header.grid(row=0, column=col_idx, padx=5, pady=5)

            if col == "status":
                options = ["запланировано", "пропущено", "отменено", "завершено"]
                selected_option = tk.StringVar(value=selected_cortege[1 + col_idx])
                status_option_menu = tk.OptionMenu(
                    input_table_win, selected_option, *options
                )
                entries[col] = selected_option
                default_entries_vals[col] = selected_option.get()
                status_option_menu.grid(row=1, column=col_idx, padx=5, pady=6)
                continue

            entry = tk.Entry(input_table_win, width=15, justify="center")
            entry.insert(0, selected_cortege[1 + col_idx])

            entries[col] = entry
            default_entries_vals[col] = entry.get()
            entry.grid(row=1, column=col_idx, padx=5, pady=6)

        cortege_id = selected_cortege[0]

        save_button = tk.Button(
            input_table_win,
            text="Save",
            command=lambda: self.save_edited_cortege(
                cortege_id, entries, default_entries_vals
            ),
        )
        save_button.grid(row=2, column=0, columnspan=len(self.table_columns), pady=10)

    def save_edited_cortege(self, cortege_id, entries, default_entries):
        try:
            for header in entries.keys():
                if entries[header].get() != default_entries[header]:
                    self.db_manager.update_record(
                        self.table_name, header, entries[header].get(), "id", cortege_id
                    )
            ms.showinfo(title="Saved", message="Data saved successfully")
            self.update_displayed_table_data()
        except Exception as e:
            ms.showerror(title="Saving data error", message="Check input data")
            print(e)

    def delete_record(self):
        selected_cortege = self.tree.selection()

        if not selected_cortege:
            ms.showerror(title="Error", message="No selected cortege")
            return

        selected_cortege = self.tree.item(selected_cortege[0], "values")

        if not ms.askyesno(
            title="Are you sure?", message="Do you really want to delete this cortege?"
        ):
            return

        try:
            self.db_manager.delete_record(self.table_name, "id", selected_cortege[0])
            self.notebook.update_all_tables()
        except Exception as e:
            ms.showerror(title="Error", message="Delete error")
            print(e)

    def find_cortege_window(self):
        input_win = tk.Toplevel(self)
        input_win.transient(self)
        input_win.title("Find a record")
        input_win.protocol(
            "WM_DELETE_WINDOW", lambda: self.destroy_search_top_win(input_win)
        )

        # Настройка сетки 4 х 2 для виджетов
        for i in range(2):
            input_win.grid_columnconfigure(i, weight=1)
        for i in range(4):
            input_win.grid_rowconfigure(i, weight=1)

        # Кнопки для подсвечивания предыдущей / следующей найденной записи
        next_prev_btns = {
            "next": tk.Button(
                input_win, text="next", state="disabled", command=self.next_found_record
            ),
            "prev": tk.Button(
                input_win,
                text="previous",
                state="disabled",
                command=self.prev_found_record,
            ),
        }

        next_prev_btns["prev"].grid(row=2, column=0, padx=5, pady=5, sticky="nsew")
        next_prev_btns["next"].grid(row=2, column=1, padx=5, pady=5, sticky="nsew")

        # Лейбл для столбца, по которому ищем
        key_column_label = tk.Label(input_win, text="Search column:")
        key_column_label.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")

        # Лейбл для значения, которое ищем
        key_value_label = tk.Label(input_win, text="Search value:")
        key_value_label.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")

        # Поле для ввода поискового значения
        key_value_entry = tk.Entry(input_win, width=15, justify="center")
        key_value_entry.grid(row=1, column=1, padx=5, pady=5, sticky="nsew")
        key_val_widget_container = {
            "widget": key_value_entry,
            "value_container": key_value_entry,
        }

        # Меню выбора ключевого столбца
        key_column = tk.StringVar(value=self.table_columns[0])
        key_column_selection_menu = tk.OptionMenu(
            input_win,
            key_column,
            *self.table_columns,
            command=lambda selection: self.update_selection_menu_child_widget_in_find_btn(
                key_val_widget_container, input_win, selection
            ),
        )
        key_column_selection_menu.config(width=15)
        key_column_selection_menu.grid(row=1, column=0, padx=5, pady=5, sticky="nsew")

        find_button = tk.Button(
            input_win,
            text="Find!",
            command=lambda: self.find_cortege(
                key_column.get(),
                key_val_widget_container["value_container"].get(),
                next_prev_btns,
            ),
        )
        find_button.grid(row=3, column=0, columnspan=2, pady=10, sticky="nsew")

    def find_cortege(self, key_col, key_val, next_prev_btns):
        try:
            self.found_records = self.db_manager.find_record(
                self.table_name, key_col, key_val
            )
            self.show_found_records(next_prev_btns)
        except Exception as e:
            ms.showerror(title="Search Error", message="Check input data")
            print(e)

    def show_found_records(self, next_prev_btns):
        tree_children = self.tree.get_children()
        self.tree.selection_remove(*tree_children)

        if not self.found_records:
            ms.showinfo(message="Nothing was found")
            return
        found_records_num = len(self.found_records)
        ms.showinfo(
            title="Found Message Number", message=f"Found {found_records_num} records"
        )

        if found_records_num == 1:
            next_prev_btns["prev"]["state"] = "disabled"
            next_prev_btns["next"]["state"] = "disabled"

        if found_records_num > 1:
            next_prev_btns["prev"]["state"] = "normal"
            next_prev_btns["next"]["state"] = "normal"

        self.highlight_record(0)

    def highlight_record(self, record_idx_in_founds_list):
        tree_children = self.tree.get_children()
        self.tree.selection_remove(*tree_children)
        tree_child_idx = self.find_tree_child_index(
            self.found_records[record_idx_in_founds_list]["id"]
        )
        self.tree.selection_set(tree_child_idx)
        self.currentHighlightedRecordID = record_idx_in_founds_list
        self.tree.see(tree_child_idx)

    def destroy_search_top_win(self, top):
        self.found_records = []
        self.currentHighlightedRecordID = -1
        top.destroy()

    def find_tree_child_index(self, record_id):
        for tree_child_idx in self.tree.get_children():
            record_values = self.tree.item(tree_child_idx, "values")
            if int(record_values[0]) == record_id:
                return tree_child_idx
        return None

    def next_found_record(self):
        if self.found_records:
            self.currentHighlightedRecordID = (
                self.currentHighlightedRecordID + 1
            ) % len(self.found_records)
            self.highlight_record(self.currentHighlightedRecordID)

    def prev_found_record(self):
        if self.found_records:
            self.currentHighlightedRecordID = (
                self.currentHighlightedRecordID - 1
            ) % len(self.found_records)
            self.highlight_record(self.currentHighlightedRecordID)

    def update_selection_menu_child_widget_in_find_btn(
        self, widget_container, master, selection
    ):
        old_widget = widget_container["widget"]
        old_widget.destroy()
        if selection == "status":
            statuses = ["запланировано", "пропущено", "отменено", "завершено"]
            selected_status = tk.StringVar(value=statuses[0])
            new_widget = tk.OptionMenu(master, selected_status, *statuses)
            widget_container["value_container"] = selected_status
        else:
            new_widget = tk.Entry(master, width=15, justify="center")
            widget_container["value_container"] = new_widget
        new_widget.grid(row=1, column=1, padx=5, pady=5, sticky="nsew")
        widget_container["widget"] = new_widget

    def clear_table(self):
        try:
            self.db_manager.clear_table(self.table_name)
            ms.showinfo(title="Success", message="Table cleared successfully")
            self.notebook.update_all_tables()
        except Exception as e:
            ms.showerror(title="Clearing error", message="C")
            print(e)

    def dummy_action(self):
        print("Button clicked!")
