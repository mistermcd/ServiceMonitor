# ServiceMonitor
Windows service monitoring tool

**Manage Button** 
- Clicking this button will open Notepad to the document ServiceList.txt.
- Reatart the app to load list changes.

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

**ServiceList.txt must be in the same folder as ServiceMonitor.exe**
