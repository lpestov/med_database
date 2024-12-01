import tkinter as tk

from pages import WelcomePage


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("MedDataBase")
        self.geometry("1280x720")

        self.welcome_page = WelcomePage(self)
        self.welcome_page.pack(expand=True, fill="both")


if __name__ == "__main__":
    app = App()
    app.mainloop()
