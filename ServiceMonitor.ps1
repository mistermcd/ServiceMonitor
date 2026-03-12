<#
.SYNOPSIS
    McD's Service Monitor v12.0.0.2
    A lightweight GUI utility to monitor and manage specific Windows Services defined in a text file.

.DESCRIPTION
    This script provides a real-time interface to Start, Stop, and Monitor the status of Windows Services. 
    It runs with elevated privileges to ensure it has the necessary permissions to control system services.
    It utilizes a 'ServiceList.txt' file located in the same directory to determine which services to track.

.USAGE
    1. Run the script (it will automatically request Admin privileges).
    2. If ServiceList.txt is missing, the script will create it.
    3. Click 'Manage' to open the text file and add Service Names or Display Names (one per line).
    4. Click 'Refresh' to load newly added services without restarting the app.
    5. Use 'Start All' or 'Stop All' for bulk actions, or click individual service buttons to toggle status.
    6. Status Indicators: Green (Running), Red (Stopped), Gray (Not Found/Missing).
#>

# --- Hide the Console Window ---
$memberDefinition = @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
'@
$winApi = Add-Type -MemberDefinition $memberDefinition -Name "Win32ShowWindow" -Namespace Win32Functions -PassThru
$winApi::ShowWindow($winApi::GetConsoleWindow(), 0)

# --- Self-Elevation (Run as Admin) ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    break
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ServiceFile = "$PSScriptRoot\ServiceList.txt"
if (-not (Test-Path $ServiceFile)) { 
    New-Item -Path $ServiceFile -ItemType File | Out-Null 
}

# --- Form Setup ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "McD's Service Monitor v12.0.0.2"
$Form.Size = New-Object System.Drawing.Size(420, 600)
$Form.StartPosition = "CenterScreen"
$Form.BackColor = [System.Drawing.Color]::White

$HeaderPanel = New-Object System.Windows.Forms.Panel
$HeaderPanel.Height = 65 
$HeaderPanel.Dock = "Top"

$FlowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$FlowPanel.Dock = "Fill"
$FlowPanel.AutoScroll = $true
$FlowPanel.FlowDirection = "TopDown"
$FlowPanel.WrapContents = $false

$ToolTip = New-Object System.Windows.Forms.ToolTip

# --- Logic Functions ---

function Get-ServiceObj($Name) {
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { $svc = Get-Service -DisplayName $Name -ErrorAction SilentlyContinue }
    return $svc
}

function Update-UI {
    foreach ($row in $FlowPanel.Controls) {
        if ($row.Tag) {
            $svc = Get-ServiceObj $row.Tag
            $indicator = $row.Controls[0] 
            $btn = $row.Controls[1]      

            if ($null -eq $svc) {
                $indicator.BackColor = [System.Drawing.Color]::Gray
                $ToolTip.SetToolTip($btn, "Service Not Found")
            } elseif ($svc.Status -eq "Running") {
                $indicator.BackColor = [System.Drawing.Color]::LightGreen
                $ToolTip.SetToolTip($btn, "Click to STOP")
            } else {
                $indicator.BackColor = [System.Drawing.Color]::Red
                $ToolTip.SetToolTip($btn, "Click to START")
            }
        }
    }
}

function Reload-ServiceList {
    $FlowPanel.Controls.Clear()
    $services = Get-Content $ServiceFile | Where-Object { $_.Trim() -ne "" } | Sort-Object

    if ($services.Count -eq 0) {
        $EmptyLabel = New-Object System.Windows.Forms.Label
        $EmptyLabel.Text = "(List is empty. Click Manage to add services)"
        $EmptyLabel.Size = New-Object System.Drawing.Size(380, 30)
        $EmptyLabel.TextAlign = "MiddleCenter"
        $EmptyLabel.ForeColor = [System.Drawing.Color]::Gray
        $FlowPanel.Controls.Add($EmptyLabel)
    }

    foreach ($s in $services) {
        $RowContainer = New-Object System.Windows.Forms.Panel
        $RowContainer.Size = New-Object System.Drawing.Size(380, 30)
        $RowContainer.Tag = $s

        $Indicator = New-Object System.Windows.Forms.Label
        $Indicator.Size = New-Object System.Drawing.Size(12, 12)
        $Indicator.Location = New-Object System.Drawing.Point(10, 10)
        $Indicator.BorderStyle = "FixedSingle"
        
        $SvcBtn = New-Object System.Windows.Forms.Button
        $SvcBtn.Text = $s
        $SvcBtn.Tag = $s 
        $SvcBtn.Location = New-Object System.Drawing.Point(35, 5)
        $SvcBtn.Size = New-Object System.Drawing.Size(320, 22)
        $SvcBtn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $SvcBtn.FlatStyle = "Flat"
        $SvcBtn.Font = New-Object System.Drawing.Font("Segoe UI", 8)
        
        $SvcBtn.Add_Click({ Toggle-Service $this.Tag })
        $SvcBtn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::LightBlue })
        $SvcBtn.Add_MouseLeave({ $this.BackColor = [System.Drawing.SystemColors]::Control })

        $RowContainer.Controls.Add($Indicator)
        $RowContainer.Controls.Add($SvcBtn)
        $FlowPanel.Controls.Add($RowContainer)
    }
    Update-UI
}

function Toggle-Service($ServiceName) {
    $svc = Get-ServiceObj $ServiceName
    if ($null -eq $svc) { return }
    try {
        if ($svc.Status -eq "Running") { Stop-Service -InputObject $svc -Force -ErrorAction Stop } 
        else { Start-Service -InputObject $svc -ErrorAction Stop }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Service Error")
    }
    Update-UI
}

# --- Build Header Buttons ---
[int]$btnWidth = 75 
$controls = @(
    @{ Text = "Help"; Action = { 
        $msg = "Service status bubble:`n`nGreen: Running`nRed: Stopped`nGray: Missing`n`n" +
               "- Click service name to toggle status.`n" +
               "- Click Start or Stop All then confirm.`n" +
               "- Click Manage to edit service list.`n"
        [System.Windows.Forms.MessageBox]::Show($msg, "Help") 
    }},
@{ Text = "Manage"; Action = {

    # --- Update Service List Dialog ---
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Selected Services"
    $dlg.Size = New-Object System.Drawing.Size(500,600)
    $dlg.StartPosition = "CenterParent"

    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Location = New-Object System.Drawing.Point(12,12)
    $panel.Size = New-Object System.Drawing.Size(460,500)
    $panel.AutoScroll = $true
    $panel.FlowDirection = "TopDown"
    $panel.WrapContents = $false
    $dlg.Controls.Add($panel)

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Save & Refresh"
    $btn.Location = New-Object System.Drawing.Point(180,520)
    $btn.Size = New-Object System.Drawing.Size(140,30)
    $dlg.Controls.Add($btn)

    # Load existing selections
    $preSelected = Get-Content $ServiceFile -ErrorAction SilentlyContinue

    # Get all services
    $all = Get-Service | Sort-Object DisplayName

$checkboxes = @()
$y = 0   # start at 0 for clean stacking

foreach ($svc in $all) {

    # Row container panel (fixed height, no padding)
    $cbPanel = New-Object System.Windows.Forms.Panel
    $cbPanel.Size = New-Object System.Drawing.Size(440, 20)
    $cbPanel.Location = New-Object System.Drawing.Point(10, $y)
    $cbPanel.Margin = '0,0,0,0'
    $cbPanel.Padding = '0,0,0,0'
    $cbPanel.BackColor = [System.Drawing.Color]::White

    # Checkbox
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $svc.DisplayName
    $cb.Tag  = $svc.Name
    $cb.AutoSize = $false
    $cb.Size = New-Object System.Drawing.Size(420, 20)
    $cb.Location = New-Object System.Drawing.Point(3, 2)

    # Highlight the panel, not the checkbox
    $cb.Add_CheckedChanged({
        if ($this.Checked) {
            $this.Parent.BackColor = [System.Drawing.Color]::LightGreen
        } else {
            $this.Parent.BackColor = [System.Drawing.Color]::White
        }
    })

    # Pre-check
    if ($preSelected -contains $svc.DisplayName) {
        $cb.Checked = $true
        $cbPanel.BackColor = [System.Drawing.Color]::LightGreen
    }

    # Add to UI
    $cbPanel.Controls.Add($cb)
    $panel.Controls.Add($cbPanel)

    $checkboxes += $cb

    # Move down exactly one row height
    $y += 20
}


    # Save button logic
    $btn.Add_Click({
        $selected = $checkboxes |
            Where-Object { $_.Checked } |
            ForEach-Object { $_.Text }

        Set-Content -Path $ServiceFile -Value $selected

        $dlg.Close()

        # Auto-refresh main UI
        Reload-ServiceList
    })

    $dlg.Add_Shown({ $dlg.Activate() })
    [void]$dlg.ShowDialog()

}},

    @{ Text = "Start All"; Color = "LightGreen"; Action = { 
        if(([System.Windows.Forms.MessageBox]::Show("Start all listed services?", "Confirm", 1) -eq 1)) {
            Get-Content $ServiceFile | ForEach-Object { $s = Get-ServiceObj $_; if($s){ Start-Service $s -EA 0 }}; Update-UI
        }
    }},
    @{ Text = "Stop All"; Color = "Tomato"; Action = { 
        if(([System.Windows.Forms.MessageBox]::Show("Stop all listed services?", "Confirm", 1) -eq 1)) {
            Get-Content $ServiceFile | ForEach-Object { $s = Get-ServiceObj $_; if($s){ Stop-Service $s -Force -EA 0 }}; Update-UI
        }
    }}
)

# CENTER CALCULATION
$totalWidth = $controls.Count * $btnWidth
$posX = ($Form.ClientSize.Width - $totalWidth) / 2 

foreach ($ctl in $controls) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $ctl.Text
    $b.Location = New-Object System.Drawing.Point($posX, 12) 
    $posX += $btnWidth
    $b.Size = New-Object System.Drawing.Size(($btnWidth - 4), 32)
    
    # BOLD AND BIGGER FONT
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $b.FlatStyle = "Flat"
    
    # Store the intended color in the AccessibleDescription to keep it unique to each button
    if ($ctl.Color) { 
        $b.BackColor = [System.Drawing.Color]::($ctl.Color) 
        $b.AccessibleDescription = $ctl.Color # Remember this color
    } else {
        $b.AccessibleDescription = "Control" # Remember standard color
    }
    
    $b.Add_Click($ctl.Action)
    
    # Hover logic (uses the button's own stored AccessibleDescription to reset color)
    $b.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::LightBlue })
    $b.Add_MouseLeave({ 
        if ($this.AccessibleDescription -eq "Control") {
            $this.BackColor = [System.Drawing.SystemColors]::Control
        } else {
            $this.BackColor = [System.Drawing.Color]::($this.AccessibleDescription)
        }
    })
    
    $HeaderPanel.Controls.Add($b)
}

# Timer for Auto-Refresh (Status only)
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 5000 
$Timer.Add_Tick({ Update-UI })
$Timer.Start()

$Form.Controls.Add($FlowPanel)
$Form.Controls.Add($HeaderPanel)

# Perform initial population
$Form.Add_Shown({ Reload-ServiceList })
$Form.ShowDialog()