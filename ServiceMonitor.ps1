# --- Hide the Console Window ---
$memberDefinition = @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
'@
$winApi = Add-Type -MemberDefinition $memberDefinition -Name "Win32ShowWindow" -Namespace Win32Functions -PassThru
$nCmdShow = 0 # 0 = Hidden
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
if (-not (Test-Path $ServiceFile)) { New-Item -Path $ServiceFile -ItemType File }

# --- Form Setup ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "McD's Service Monitor v11.1.1.3"
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
        $svcName = $row.Tag
        $svc = Get-ServiceObj $svcName
        # Index 0 is the Indicator, Index 1 is the Button
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
[int]$btnWidth = 75 
$controls = @(
    @{ Text = "Help"; Action = { [System.Windows.Forms.MessageBox]::Show("Service status bubble:`n`nGreen: Running`nRed: Stopped`nGray: Missing`n`nClick service name to toggle status.`nClick Manage to edit service list.", "Help") }},
    @{ Text = "Manage"; Action = { Start-Process notepad.exe $ServiceFile }},
    @{ Text = "Start All"; Action = { 
        # Confirmation Dialog
        $msg = "This affects ALL services, are you sure?"
        $result = [System.Windows.Forms.MessageBox]::Show($msg, "Confirm Start All", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
        
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Get-Content $ServiceFile | ForEach-Object { $s = Get-ServiceObj $_; if($s){ Start-Service -InputObject $s -ErrorAction SilentlyContinue }}
            Update-UI 
        }
    }},
    @{ Text = "Stop All"; Action = { 
        # Confirmation Dialog
        $msg = "This affects ALL services, are you sure?"
        $result = [System.Windows.Forms.MessageBox]::Show($msg, "Confirm Stop All", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
        
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Get-Content $ServiceFile | ForEach-Object { $s = Get-ServiceObj $_; if($s){ Stop-Service -InputObject $s -Force -ErrorAction SilentlyContinue }}
            Update-UI 
        }
    }}
)

$posX = 320
foreach ($ctl in $controls) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $ctl.Text
    $b.Location = New-Object System.Drawing.Point(($posX - $btnWidth), 10)
    $posX -= $btnWidth
    $b.Size = New-Object System.Drawing.Size(($btnWidth - 5), 30)
    $b.Add_Click($ctl.Action)
    $b.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::LightBlue })
    $b.Add_MouseLeave({ $this.BackColor = [System.Drawing.SystemColors]::Control })
    $HeaderPanel.Controls.Add($b)
}

# --- Load Service List ---
$services = Get-Content $ServiceFile | Where-Object { $_.Trim() -ne "" } | Sort-Object

foreach ($s in $services) {
    $RowContainer = New-Object System.Windows.Forms.Panel
    $RowContainer.Size = New-Object System.Drawing.Size(380, 30)
    $RowContainer.Tag = $s # Assign name to the row

    $Indicator = New-Object System.Windows.Forms.Label
    $Indicator.Size = New-Object System.Drawing.Size(15, 15)
    $Indicator.Location = New-Object System.Drawing.Point(10, 12)
    $Indicator.BorderStyle = "FixedSingle"
    
    $SvcBtn = New-Object System.Windows.Forms.Button
    $SvcBtn.Text = $s
    $SvcBtn.Tag = $s # <--- CRITICAL: Pin the service name to THIS specific button
    $SvcBtn.Location = New-Object System.Drawing.Point(35, 5)
    $SvcBtn.Size = New-Object System.Drawing.Size(320, 25)
    $SvcBtn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $SvcBtn.FlatStyle = "Flat"
    
    # Use $this.Tag so the button knows exactly which service it belongs to
    $SvcBtn.Add_Click({ Toggle-Service $this.Tag })
    
    $SvcBtn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::LightBlue })
    $SvcBtn.Add_MouseLeave({ $this.BackColor = [System.Drawing.SystemColors]::Control })

    $RowContainer.Controls.Add($Indicator) # Index 0
    $RowContainer.Controls.Add($SvcBtn)    # Index 1
    $FlowPanel.Controls.Add($RowContainer)
}

# Timer for Auto-Refresh
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 5000 
$Timer.Add_Tick({ Update-UI })
$Timer.Start()

$Form.Controls.Add($FlowPanel)
$Form.Controls.Add($HeaderPanel)
$Form.Add_Shown({ Update-UI })
$Form.ShowDialog()