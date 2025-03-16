import tkinter as tk
from tkinter import messagebox
import psutil
import win32serviceutil
import tkinter.font as tkFont
import os
import subprocess

SERVICE_FILE = "ServiceList.txt"

# Tooltip class for displaying contextual tooltips
class Tooltip:
    def __init__(self, widget):
        self.widget = widget
        self.tip_window = None
        self.text = ""
        self.widget.bind("<Enter>", self.on_enter)
        self.widget.bind("<Leave>", self.hide_tip)
        self.widget.bind("<Motion>", self.on_motion)

    def on_enter(self, event):
        self.show_tip(self.text, event)

    def on_motion(self, event):
        if self.tip_window:
            x, y = event.x_root + 10, event.y_root + 10
            self.tip_window.wm_geometry(f"+{x}+{y}")

    def show_tip(self, text, event):
        self.text = text
        if self.tip_window:
            self.hide_tip()

        x, y = event.x_root + 10, event.y_root + 10
        self.tip_window = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(True)
        tw.wm_geometry(f"+{x}+{y}")

        label = tk.Label(tw, text=text, background="lightyellow", relief="solid", borderwidth=1, font=("Arial", 10))
        label.pack()

    def hide_tip(self, event=None):
        if self.tip_window:
            self.tip_window.destroy()
            self.tip_window = None

# Main application class
class ServiceMonitorApp:
    def __init__(self, root):
        # Initialize the application window and core variables
        self.root = root
        self.root.title("McD's Service Monitor")
        self.root.geometry("400x600")
        self.service_map = self.get_service_mapping()
        self.services = self.load_services()
        self.service_widgets = {}
        
        # Create the UI components
        self.create_main_ui()
        self.create_ui()
        self.update_service_status()

    # Get a mapping of service display names to actual service names
    def get_service_mapping(self):
        return {service.display_name(): service.name() for service in psutil.win_service_iter()}

    # Load and alphabetically sort services from the service list file
    def load_services(self):
        try:
            with open(SERVICE_FILE, "r") as file:
                service_list = sorted([line.strip() for line in file if line.strip()])
                return {name: self.service_map.get(name, name) for name in service_list}
        except FileNotFoundError:
            messagebox.showerror("Error", f"File '{SERVICE_FILE}' not found!")
            return {}

    # Create the main UI layout
    def create_main_ui(self):
        self.main_frame = tk.Frame(self.root)
        self.main_frame.pack(fill="both", expand=True)
        self.header_frame = tk.Frame(self.main_frame)
        self.header_frame.pack(fill="x", padx=10, pady=5)

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

        self.help_button = tk.Button(self.header_frame, text="Help", command=self.show_help)
        self.help_button.pack(side="right", padx=5)
        self.apply_hover_effect(self.help_button)

        self.canvas = tk.Canvas(self.main_frame)
        self.canvas.pack(side="left", fill="both", expand=True)

        self.scrollbar = tk.Scrollbar(self.main_frame, orient="vertical", command=self.canvas.yview)
        self.scrollbar.pack(side="right", fill="y")

        self.canvas.configure(yscrollcommand=self.scrollbar.set)
        self.button_frame = tk.Frame(self.canvas)
        self.canvas.create_window((0, 0), window=self.button_frame, anchor="nw")

        self.canvas.bind_all("<MouseWheel>", self.on_mouse_wheel)

    # Create the UI elements for services
    def create_ui(self):
        for widget in self.button_frame.winfo_children():
            widget.destroy()
        self.service_widgets.clear()
        test_font = tkFont.nametofont("TkDefaultFont")
        # Pad the button width by 20 pixels
        button_width = max(20, max(test_font.measure(name) for name in self.services.keys()) // 8) + 20
        for friendly_name, actual_name in self.services.items():
            frame = tk.Frame(self.button_frame)
            frame.pack(pady=5, padx=10, anchor="w")

            canvas = tk.Canvas(frame, width=20, height=20, highlightthickness=0)
            indicator = canvas.create_oval(2, 2, 18, 18, fill="gray")
            canvas.pack(side="left")

            btn = tk.Button(frame, text=friendly_name, width=button_width, command=lambda svc=actual_name: self.toggle_service(svc))
            btn.pack(side="left", padx=10)

            self.update_tooltip(btn, actual_name)
            self.apply_hover_effect(btn)

            self.service_widgets[actual_name] = (canvas, indicator, btn)

        self.button_frame.update_idletasks()
        self.canvas.config(scrollregion=self.canvas.bbox("all"))

    # Update the status of services and refresh the UI
    def update_service_status(self):
        for service_name, (canvas, indicator, btn) in self.service_widgets.items():
            status = self.get_service_status(service_name)
            color = "lightgreen" if status else "red" if status is not None else "gray"
            canvas.itemconfig(indicator, fill=color)
            tooltip_text = "Click to STOP" if status else "Click to START"
            btn.tooltip.text = tooltip_text
        self.button_frame.update_idletasks()
        self.canvas.config(scrollregion=self.canvas.bbox("all"))
        self.root.after(10000, self.update_service_status)

    # Get the status of a service
    def get_service_status(self, service_name):
        try:
            service = psutil.win_service_get(service_name)
            return service.status() == "running"
        except Exception:
            return None

    # Toggle the state of a service (start/stop)
    def toggle_service(self, service_name):
        try:
            service = psutil.win_service_get(service_name)
            if service.status() == "running":
                win32serviceutil.StopService(service_name)
            else:
                win32serviceutil.StartService(service_name)
        except Exception as e:
            messagebox.showerror("Error", f"Failed to control service '{service_name}': {str(e)}")
        finally:
            self.update_service_status()

    # Start all services in the list
    def start_all(self):
        for service_name in self.services.values():
            try:
                win32serviceutil.StartService(service_name)
            except Exception:
                continue
        self.update_service_status()

    # Stop all services in the list
    def stop_all(self):
        for service_name in self.services.values():
            try:
                win32serviceutil.StopService(service_name)
            except Exception:
                continue
        self.update_service_status()

    # Open the service list file in Notepad
    def open_service_file(self):
        if not os.path.exists(SERVICE_FILE):
            with open(SERVICE_FILE, "w") as f:
                f.write("")
        subprocess.Popen(["notepad.exe", SERVICE_FILE])

    # Update the tooltip text for a button
    def update_tooltip(self, button, service_name):
        status = self.get_service_status(service_name)
        tooltip_text = "Click to STOP" if status else "Click to START"
        if hasattr(button, "tooltip"):
            button.tooltip.text = tooltip_text
        else:
            button.tooltip = Tooltip(button)

    # Apply hover effects to buttons
    def apply_hover_effect(self, button):
        def on_enter(event):
            button.config(bg="lightblue")
            if hasattr(button, "tooltip"):
                button.tooltip.show_tip(button.tooltip.text, event)

        def on_leave(event):
            button.config(bg="SystemButtonFace")
            if hasattr(button, "tooltip"):
                button.tooltip.hide_tip()

        button.bind("<Enter>", on_enter)
        button.bind("<Leave>", on_leave)

    # Enable the mouse wheel
    def on_mouse_wheel(self, event):
        self.canvas.yview_scroll(-1 if event.delta > 0 else 1, "units")

    # Help Dialog
    def show_help(self):
        help_msg = """Service State GREEN - running
Service State RED      - stopped
Service State GRAY    - unknown

Click a service button to toggle state
Click STOP ALL to Stop all Services
Click START ALL to Start all Services
    
Click MANAGE to edit the Service List    
Restart Service Monitor after list edit!"""
        messagebox.showinfo("Service Manager Help",help_msg)        

if __name__ == "__main__":
    root = tk.Tk()
    app = ServiceMonitorApp(root)
    root.mainloop()
