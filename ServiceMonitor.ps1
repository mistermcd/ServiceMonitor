<#
.SYNOPSIS
    McD's Service Monitor v11.1.1.4
    A lightweight GUI utility to monitor and manage specific Windows Services defined in a text file.
    Originally developed in Python and then Gemini and CoPilot took turns converting it to powershell.

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
$nCmdShow = 0 
$winApi::ShowWindow($winApi::GetConsoleWindow(), $nCmdShow)

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
    [System.Windows.Forms.MessageBox]::Show("ServiceList.txt was not found and has been created. Please click 'Manage' to add services.", "File Created")
}

# --- Form Setup ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "McD's Service Monitor v11.1.1.4"
$Form.Size = New-Object System.Drawing.Size(420, 600)
$Form.StartPosition = "CenterScreen"
$Form.BackColor = [System.Drawing.Color]::White

$HeaderPanel = New-Object System.Windows.Forms.Panel
$HeaderPanel.Height = 50
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
            $svcName = $row.Tag
            $svc = Get-ServiceObj $svcName
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
        if ($svc.Status -eq "Running") {
            Stop-Service -InputObject $svc -Force -ErrorAction Stop
        } else {
            Start-Service -InputObject $svc -ErrorAction Stop
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Service Error")
    }
    Update-UI
}

# --- Build Header Buttons ---
[int]$btnWidth = 70 
$controls = @(
    @{ Text = "Help"; Action = { 
        $msg = "Service status bubble:`n`nGreen: Running`nRed: Stopped`nGray: Missing`n`n" +
               "- Click service name to toggle status.`n" +
               "- Click Manage to edit service list.`n" +
               "- Click Refresh to reload names from file."
        [System.Windows.Forms.MessageBox]::Show($msg, "Help") 
    }},
    @{ Text = "Refresh"; Action = { Reload-ServiceList }},
    @{ Text = "Manage"; Action = { Start-Process notepad.exe $ServiceFile }},
    @{ Text = "Start All"; Action = { 
        $result = [System.Windows.Forms.MessageBox]::Show("This affects ALL services, are you sure?", "Confirm Start All", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Get-Content $ServiceFile | ForEach-Object { $s = Get-ServiceObj $_; if($s){ Start-Service -InputObject $s -ErrorAction SilentlyContinue }}
            Update-UI 
        }
    }},
    @{ Text = "Stop All"; Action = { 
        $result = [System.Windows.Forms.MessageBox]::Show("This affects ALL services, are you sure?", "Confirm Stop All", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Get-Content $ServiceFile | ForEach-Object { $s = Get-ServiceObj $_; if($s){ Stop-Service -InputObject $s -Force -ErrorAction SilentlyContinue }}
            Update-UI 
        }
    }}
)

# CENTER CALCULATION:
$totalWidth = $controls.Count * $btnWidth
$posX = ($Form.ClientSize.Width - $totalWidth) / 2 

foreach ($ctl in $controls) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $ctl.Text
    $b.Location = New-Object System.Drawing.Point($posX, 10) 
    $posX += $btnWidth
    $b.Size = New-Object System.Drawing.Size(($btnWidth - 5), 28) 
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 7) 
    $b.Add_Click($ctl.Action)
    $b.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::LightBlue })
    $b.Add_MouseLeave({ $this.BackColor = [System.Drawing.SystemColors]::Control })
    $HeaderPanel.Controls.Add($b)
}

$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 5000
$Timer.Add_Tick({ Update-UI })
$Timer.Start()

$Form.Controls.Add($FlowPanel)
$Form.Controls.Add($HeaderPanel)

$Form.Add_Shown({ Reload-ServiceList })
$Form.ShowDialog()