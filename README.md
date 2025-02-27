# ServiceMonitor
Windows service monitoring tool

**Manage Button** 
- Clicking this button will open Notepad to the document ServiceList.txt.
- The ServiceMonitor app will reload the list dynamically so you do not need to restart the app.

**Start All**
- Cicking this button will start all the services in the list
- Errors are suppressed on bulk operations so if any service fails, we move on to the next.

**Stop all**
- Clicking this button will stop all the services in the list
- Errors are suppressed on bulk operations so if any service fails, we move on to the next.

**Status Bubble Indicators**
- RED - service is stopped
- GREEN - service is started
- GREY - service status unknown

**Individual Service Buttons**
- Click any individual service to toggle its current status
- Tooltip will show 'Click to STOP' or 'Click to START'

If you have more services than will fit in a 400x600 window, a vertical scrollbar will be displayed.
- the vertical scrollbar can be activated with the mousewheel

Service list changes and service status updates occur on a 10 second cadence.

**Use Windows Service Friendly Names in the ServiceList.txt**



This script creates a **Windows GUI application** using **Tkinter** to monitor and toggle the state of Windows services. It reads service names from a file (`ServiceList.txt`), displays them with status indicators, and allows users to start/stop services.

----------

## **1. Importing Required Libraries**

`import tkinter as tk
from tkinter import messagebox
import psutil
import win32serviceutil
import tkinter.font as tkFont
import os
import subprocess` 

-   **tkinter** – Standard GUI library for Python.
-   **messagebox** – Provides popup alerts/messages in the GUI.
-   **psutil** – Retrieves system information, including Windows services.
-   **win32serviceutil** – Controls Windows services (start/stop).
-   **tkinter.font** – Handles text measurements for UI elements.
-   **os** – For file operations (e.g., checking if a file exists).
-   **subprocess** – Opens external applications like Notepad.

----------

## **2. Defining Constants**

`SERVICE_FILE = "ServiceList.txt"` 

-   Defines the **service list file** where service names are stored.

----------

## **3. Tooltip Class**

`class Tooltip:
    def __init__(self, widget):
        self.widget = widget
        self.tip_window = None
        self.text = ""
        self.widget.bind("<Enter>", self.on_enter)
        self.widget.bind("<Leave>", self.hide_tip)  
        self.widget.bind("<Motion>", self.on_motion)` 

-   A **tooltip** appears when hovering over a button, providing hints.
-   Binds events:
    -   `<Enter>` → Show tooltip.
    -   `<Leave>` → Hide tooltip.
    -   `<Motion>` → Moves tooltip dynamically with the cursor.

----------

 `def show_tip(self, text, event):
        self.text = text
        if self.tip_window:
            self.hide_tip()

        x, y = event.x_root + 10, event.y_root + 10
        self.tip_window = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(True)
        tw.wm_geometry(f"+{x}+{y}")

        label = tk.Label(tw, text=text, background="lightyellow", relief="solid", borderwidth=1, font=("Arial", 10))
        label.pack()` 

-   **Creates a tooltip window** at the cursor position (`x_root + 10, y_root + 10`).
-   Uses `Toplevel` to create a small pop-up label.
-   `wm_overrideredirect(True)` → Removes the window border.
-   Tooltip text is styled (`lightyellow` background).

----------

 `def hide_tip(self, event=None):
        if self.tip_window:
            self.tip_window.destroy()
            self.tip_window = None` 

-   **Destroys the tooltip** when the cursor moves away.

----------

## **4. ServiceMonitorApp Class**

### **Initializing the GUI**

`class ServiceMonitorApp:
    def __init__(self, root):
        self.root = root
        self.root.title("McDs Service Monitor")
        self.root.geometry("400x600")` 

-   Initializes the **Tkinter root window** with a title and size.

----------

 `self.service_map = self.get_service_mapping()
        self.services = self.load_services()
        self.service_widgets = {}` 

-   **Retrieves service names** and their internal identifiers.
-   **Loads service list** from `ServiceList.txt`.
-   **Creates an empty dictionary** to store UI elements for each service.

----------

 `self.button_width = self.get_max_button_width() + 20` 

-   **Determines button width** based on the longest service name.

----------

### **Creating the UI Layout**

 `self.main_frame = tk.Frame(self.root)
        self.main_frame.pack(fill="both", expand=True)` 

-   Creates the **main container frame** to hold all widgets.

----------

#### **Header Section**

 `self.header_frame = tk.Frame(self.main_frame)
        self.header_frame.pack(fill="x", padx=10, pady=5, anchor="w")

        self.label = tk.Label(self.header_frame, text="Services", font=("Arial", 12, "bold"))
        self.label.pack(side="left", padx=(0, 10))` 

-   **Header section** containing a title label.

----------

 `self.stop_all_button = tk.Button(self.header_frame, text="Stop All", command=self.stop_all)
        self.stop_all_button.pack(side="right", padx=5)
        self.apply_hover_effect(self.stop_all_button)

        self.start_all_button = tk.Button(self.header_frame, text="Start All", command=self.start_all)
        self.start_all_button.pack(side="right", padx=5)
        self.apply_hover_effect(self.start_all_button)` 

-   **Buttons to start/stop all services** in the list.
-   Calls `self.stop_all()` and `self.start_all()` when clicked.
-   Hover effect is applied.

----------

 `self.manage_button = tk.Button(self.header_frame, text="Manage", command=self.open_service_file)
        self.manage_button.pack(side="right", padx=5)
        self.apply_hover_effect(self.manage_button)` 

-   **"Manage" button** opens `ServiceList.txt` in Notepad for editing.

----------

### **Scrollable Canvas for Services**

 `self.canvas = tk.Canvas(self.main_frame)
        self.canvas.pack(side="left", fill="both", expand=True)

        self.scrollbar = tk.Scrollbar(self.main_frame, orient="vertical", command=self.canvas.yview)
        self.scrollbar.pack(side="right", fill="y")

        self.canvas.configure(yscrollcommand=self.scrollbar.set)` 

-   **Creates a scrollable area** to display services dynamically.

----------

## **5. Service Handling Functions**

### **Fetching Windows Services**

 `def get_service_mapping(self):
        service_map = {}
        for service in psutil.win_service_iter():
            service_map[service.display_name()] = service.name()
        return service_map` 

-   Retrieves all Windows services and maps **display names** to **actual service names**.

----------

### **Loading Services from File**

 `def load_services(self):
        try:
            with open(SERVICE_FILE, "r") as file:
                service_list = [line.strip() for line in file if line.strip()]
                return {name: self.service_map.get(name, name) for name in service_list}
        except FileNotFoundError:
            messagebox.showerror("Error", f"File '{SERVICE_FILE}' not found!")
            return {}` 

-   Reads `ServiceList.txt`, removes blank lines, and maps each service name to its system name.

----------

### **Checking Service Status**

 `def get_service_status(self, service_name):
        try:
            service = psutil.win_service_get(service_name)
            return service.status() == "running"
        except Exception:
            return None  # Unknown service status` 

-   Uses `psutil` to check if a service is running.

----------

### **Updating Service Status Indicators**

 `def update_service_status(self):
        new_service_map = self.get_service_mapping()
        new_services = self.load_services()

        if new_services != self.services:
            self.service_map = new_service_map
            self.services = new_services
            self.create_ui()

        for service, (canvas, indicator, btn) in self.service_widgets.items():
            status = self.get_service_status(service)
            color = "lightgreen" if status else "red" if status is not None else "gray"
            canvas.itemconfig(indicator, fill=color)
            self.update_tooltip(btn, service)

        self.root.after(10000, self.update_service_status)` 

-   Updates **status indicators** (green = running, red = stopped, gray = unknown).
-   Refreshes **every 10 seconds**.

----------

### **Starting and Stopping Services**

 `def toggle_service(self, service_name):
        try:
            service = psutil.win_service_get(service_name)
            if service.status() == "running":
                win32serviceutil.StopService(service_name)
            else:
                win32serviceutil.StartService(service_name)
        except Exception as e:
            messagebox.showerror("Error", f"Failed to control service '{service_name}':\n{str(e)}")
        
        self.update_service_status()` 

-   **Toggles a service's state** (running ↔ stopped).
-   Uses `win32serviceutil` for controlling services.

----------

## **6. Running the Application**

`if __name__ == "__main__":
    root = tk.Tk()
    app = ServiceMonitorApp(root)
    root.mainloop()` 

-   **Creates the GUI window** and starts the application.
