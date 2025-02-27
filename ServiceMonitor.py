import tkinter as tk
from tkinter import messagebox
import psutil
import win32serviceutil
import tkinter.font as tkFont
import os
import subprocess

SERVICE_FILE = "ServiceList.txt"

class ServiceMonitorApp:
    def __init__(self, root):
        self.root = root
        self.root.title("McDs Service Monitor")
        self.root.geometry("400x600")

        self.service_map = self.get_service_mapping()
        self.services = self.load_services()
        self.service_widgets = {}

        self.button_width = self.get_max_button_width() + 20

        self.main_frame = tk.Frame(self.root)
        self.main_frame.pack(fill="both", expand=True)

        self.header_frame = tk.Frame(self.main_frame)
        self.header_frame.pack(fill="x", padx=10, pady=5, anchor="w")

        self.label = tk.Label(self.header_frame, text="Services", font=("Arial", 12, "bold"))
        self.label.pack(side="left", padx=(0, 10))

        self.stop_all_button = tk.Button(self.header_frame, text="Stop All", command=self.stop_all)
        self.stop_all_button.pack(side="right", padx=5)
        self.apply_hover_effect(self.stop_all_button)
        
        self.start_all_button = tk.Button(self.header_frame, text="Start All", command=self.start_all)
        self.start_all_button.pack(side="right", padx=5)
        self.apply_hover_effect(self.start_all_button)

        self.manage_button = tk.Button(self.header_frame, text="Manage", command=self.open_service_file)
        self.manage_button.pack(side="right", padx=5)
        self.apply_hover_effect(self.manage_button)

        self.canvas = tk.Canvas(self.main_frame)
        self.canvas.pack(side="left", fill="both", expand=True)

        self.scrollbar = tk.Scrollbar(self.main_frame, orient="vertical", command=self.canvas.yview)
        self.scrollbar.pack(side="right", fill="y")

        self.canvas.configure(yscrollcommand=self.scrollbar.set)

        self.button_frame = tk.Frame(self.canvas)
        self.canvas.create_window((0, 0), window=self.button_frame, anchor="nw")

        self.create_ui()
        self.update_service_status()

        self.button_frame.update_idletasks()
        self.canvas.config(scrollregion=self.canvas.bbox("all"))

        self.canvas.bind_all("<MouseWheel>", self.on_mouse_wheel)

    def get_service_mapping(self):
        service_map = {}
        for service in psutil.win_service_iter():
            service_map[service.display_name()] = service.name()
        return service_map

    def load_services(self):
        try:
            with open(SERVICE_FILE, "r") as file:
                service_list = [line.strip() for line in file if line.strip()]
                return {name: self.service_map.get(name, name) for name in service_list}
        except FileNotFoundError:
            messagebox.showerror("Error", f"File '{SERVICE_FILE}' not found!")
            return {}

    def get_max_button_width(self):
        if not self.services:
            return 20

        test_font = tkFont.nametofont("TkDefaultFont")
        max_width = max(test_font.measure(name) for name in self.services.keys())

        return max(20, max_width // 8)

    def create_ui(self):
        for widget in self.button_frame.winfo_children():
            widget.destroy()

        self.service_widgets.clear()

        sorted_services = sorted(self.services.items())

        for friendly_name, actual_name in sorted_services:
            frame = tk.Frame(self.button_frame)
            frame.pack(pady=5, padx=10, anchor="w")

            canvas = tk.Canvas(frame, width=20, height=20, highlightthickness=0)
            indicator = canvas.create_oval(2, 2, 18, 18, fill="lightgreen")
            canvas.pack(side="left")

            btn = tk.Button(frame, text=friendly_name, width=self.button_width,
                            command=lambda svc=actual_name: self.toggle_service(svc))
            btn.pack(side="left", padx=10)
            self.apply_hover_effect(btn)

            self.service_widgets[actual_name] = (canvas, indicator)

    def get_service_status(self, service_name):
        try:
            service = psutil.win_service_get(service_name)
            return service.status() == "running"
        except Exception:
            return None

    def update_service_status(self):
        new_service_map = self.get_service_mapping()
        new_services = self.load_services()

        # Check if the service list has changed
        if new_services != self.services:
            self.service_map = new_service_map
            self.services = new_services

            # Rebuild the UI only if there's a change
            for widget in self.button_frame.winfo_children():
                widget.destroy()
            self.create_ui()

        # Update only the status bubbles
        for service, (canvas, indicator) in self.service_widgets.items():
            status = self.get_service_status(service)
            color = "lightgreen" if status else "red" if status is not None else "gray"
            canvas.itemconfig(indicator, fill=color)

        # Schedule the next update in 10 seconds
        self.root.after(10000, self.update_service_status)

    def toggle_service(self, service_name):
        try:
            service = psutil.win_service_get(service_name)
            if service.status() == "running":
                win32serviceutil.StopService(service_name)
            else:
                win32serviceutil.StartService(service_name)
        except Exception:
            messagebox.showerror("Error", f"Failed to control service '{service_name}':\n{str(e)}")
        self.update_service_status()

    def start_all(self):
        for service_name in self.services.values():
            try:
                win32serviceutil.StartService(service_name)
            except Exception:
                pass # Suppress errors when doing bulk operations
        self.update_service_status()

    def stop_all(self):
        for service_name in self.services.values():
            try:
                win32serviceutil.StopService(service_name)
            except Exception:
                pass # Suppress errors when doing bulk operations
        self.update_service_status()

    def open_service_file(self):
        if not os.path.exists(SERVICE_FILE):
            with open(SERVICE_FILE, "w") as f:
                f.write("")
        subprocess.Popen(["notepad.exe", SERVICE_FILE])

    def apply_hover_effect(self, button):
        button.bind("<Enter>", lambda e: button.config(bg="lightblue"))
        button.bind("<Leave>", lambda e: button.config(bg="SystemButtonFace"))

    def on_mouse_wheel(self, event):
        self.canvas.yview_scroll(-1 if event.delta > 0 else 1, "units")

if __name__ == "__main__":
    root = tk.Tk()
    app = ServiceMonitorApp(root)
    root.mainloop()
