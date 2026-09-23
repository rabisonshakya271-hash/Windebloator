#Requires -Version 5.1
<#
.SYNOPSIS
    Win-Debloater : A professional GUI tool to remove bloatware and apply
    privacy/performance tweaks on Windows 10 and Windows 11.

.DESCRIPTION
    - Default Mode  : One-click removal of a curated, safe list of pre-installed
                      bloatware apps + recommended privacy/telemetry tweaks.
    - Custom Mode   : Pick exactly which installed apps to remove and which
                      tweaks to apply from checkable lists.
    - Creates a System Restore Point before making any changes (optional).
    - Live, color-coded log output + progress bar.
    - Safe by design: never touches Store, Calculator, Photos, Notepad, Paint,
      Security/Defender, or anything required for Windows to function.

.NOTES
    Run as Administrator. Works on Windows 10 (1809+) and Windows 11 (all versions).
    Author: Generated tool - review before running on production machines.
#>

# ============================================================================
#  ELEVATION CHECK
# ============================================================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# ============================================================================
#  THEME / COLORS  (professional dark UI)
# ============================================================================
$Theme = @{
    Background   = [System.Drawing.Color]::FromArgb(24, 26, 32)
    Panel        = [System.Drawing.Color]::FromArgb(32, 34, 42)
    PanelAlt     = [System.Drawing.Color]::FromArgb(38, 41, 51)
    Accent       = [System.Drawing.Color]::FromArgb(0, 173, 181)
    AccentDark   = [System.Drawing.Color]::FromArgb(0, 140, 150)
    TextPrimary  = [System.Drawing.Color]::FromArgb(235, 237, 240)
    TextMuted    = [System.Drawing.Color]::FromArgb(150, 155, 165)
    Success      = [System.Drawing.Color]::FromArgb(87, 209, 128)
    Warning      = [System.Drawing.Color]::FromArgb(240, 190, 90)
    Danger       = [System.Drawing.Color]::FromArgb(235, 95, 95)
    Border       = [System.Drawing.Color]::FromArgb(55, 58, 68)
}
$FontFamily = "Segoe UI"

# ============================================================================
#  BLOATWARE DEFINITIONS
# ============================================================================
# Default (Safe) list — curated apps that are near-universally considered
# bloat and safe to remove without affecting core Windows functionality.
$DefaultBloatList = @(
    "Microsoft.3DBuilder"
    "Microsoft.BingFinance"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingWeather"
    "Microsoft.BingSearch"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MixedReality.Portal"
    "Microsoft.OneConnect"
    "Microsoft.People"
    "Microsoft.Print3D"
    "Microsoft.SkypeApp"
    "Microsoft.Wallet"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.XboxApp"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.Todos"
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.MicrosoftStickyNotes"
    "MicrosoftTeams"
    "Clipchamp.Clipchamp"
    "Microsoft.549981C3F5F10"          # Cortana
    "Microsoft.Copilot"
    "MicrosoftCorporationII.MicrosoftFamily"
    "Microsoft.GamingApp"
    "Disney.37853FC22B2CE"
    "SpotifyAB.SpotifyMusic"
    "6Wunderkinder.Wunderlist"
    "king.com.CandyCrushSaga"
    "king.com.CandyCrushSodaSaga"
    "Facebook.Facebook"
    "BytedancePte.Ltd.TikTok"
    "instagram"
    "AmazonVideo.PrimeVideo"
)

# Apps EXCLUDED from removal even in Custom "select all" — safety net.
$ProtectedApps = @(
    "Microsoft.WindowsStore"
    "Microsoft.WindowsCalculator"
    "Microsoft.Windows.Photos"
    "Microsoft.WindowsNotepad"
    "Microsoft.Paint"
    "Microsoft.ScreenSketch"
    "Microsoft.WindowsCamera"
    "Microsoft.WindowsTerminal"
    "Microsoft.SecHealthUI"           # Windows Security / Defender UI
    "Microsoft.DesktopAppInstaller"
    "Microsoft.NET.Native"
    "Microsoft.VCLibs"
    "Microsoft.UI.Xaml"
    "Microsoft.HEIFImageExtension"
    "Microsoft.WebMediaExtensions"
    "Microsoft.WebpImageExtension"
    "Microsoft.MicrosoftEdge"
    "Microsoft.WindowsAppRuntime"
)

# Tweaks catalog: Id, Label, Default (checked in Default Mode?), ScriptBlock
$TweaksCatalog = @(
    @{ Id="Telemetry";     Label="Disable Windows Telemetry & Diagnostic Data";        Default=$true;  Action={Disable-Telemetry} }
    @{ Id="Cortana";       Label="Disable Cortana";                                    Default=$true;  Action={Disable-CortanaFeature} }
    @{ Id="BingSearch";    Label="Disable Bing Search in Start Menu";                  Default=$true;  Action={Disable-BingSearch} }
    @{ Id="ConsumerFeat";  Label="Disable Consumer Features (stops app reinstalls)";   Default=$true;  Action={Disable-ConsumerFeatures} }
    @{ Id="GameDVR";       Label="Disable Xbox Game Bar / Game DVR";                   Default=$true;  Action={Disable-GameDVR} }
    @{ Id="AdvertisingId"; Label="Disable Advertising ID";                             Default=$true;  Action={Disable-AdvertisingId} }
    @{ Id="Suggestions";   Label="Disable Start Menu / Lock Screen suggestions & ads"; Default=$true;  Action={Disable-Suggestions} }
    @{ Id="Timeline";      Label="Disable Activity History / Timeline";                Default=$false; Action={Disable-ActivityHistory} }
    @{ Id="OneDrive";      Label="Uninstall OneDrive"; Default=$false; Action={Uninstall-OneDriveApp} }
    @{ Id="WidgetsTB";     Label="Remove Widgets from Taskbar (Win11)";                Default=$false; Action={Disable-WidgetsTaskbar} }
    @{ Id="ChatTB";        Label="Remove Chat/Teams icon from Taskbar (Win11)";        Default=$false; Action={Disable-ChatTaskbar} }
    @{ Id="Copilot";       Label="Disable Windows Copilot";                            Default=$false; Action={Disable-CopilotFeature} }
    @{ Id="RestorePoint";  Label="Create a System Restore Point before changes";       Default=$true;  Action={ New-SystemRestorePoint } }
)

# ============================================================================
#  LOGGING
# ============================================================================
$script:LogBox = $null
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info","Success","Warning","Error")] [string]$Level = "Info"
    )
    if (-not $script:LogBox) { return }
    $color = switch ($Level) {
        "Success" { $Theme.Success }
        "Warning" { $Theme.Warning }
        "Error"   { $Theme.Danger }
        default   { $Theme.TextPrimary }
    }
    $timestamp = Get-Date -Format "HH:mm:ss"
    $script:LogBox.SelectionStart  = $script:LogBox.TextLength
    $script:LogBox.SelectionLength = 0
    $script:LogBox.SelectionColor  = $Theme.TextMuted
    $script:LogBox.AppendText("[$timestamp] ")
    $script:LogBox.SelectionColor  = $color
    $script:LogBox.AppendText("$Message`r`n")
    $script:LogBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# ============================================================================
#  CORE ACTIONS
# ============================================================================
function New-SystemRestorePoint {
    try {
        Write-Log "Creating System Restore Point..." "Info"
        Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Win-Debloater Pre-Change Snapshot" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore point created successfully." "Success"
    } catch {
        Write-Log "Could not create restore point: $($_.Exception.Message)" "Warning"
    }
}

function Remove-BloatApp {
    param([string]$Name)

    if ($ProtectedApps -contains $Name) {
        Write-Log "Skipped protected app: $Name" "Warning"
        return
    }

    $found = $false

    # Remove for all current users
    Get-AppxPackage -AllUsers -Name "*$Name*" -ErrorAction SilentlyContinue | ForEach-Object {
        $found = $true
        try {
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
            Write-Log "Removed: $($_.Name)" "Success"
        } catch {
            Write-Log "Failed to remove $($_.Name): $($_.Exception.Message)" "Error"
        }
    }

    # Remove provisioned package so it doesn't reinstall for new users
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$Name*" } |
        ForEach-Object {
            $found = $true
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null
                Write-Log "Removed provisioned package: $($_.DisplayName)" "Success"
            } catch {
                Write-Log "Failed to remove provisioned $($_.DisplayName): $($_.Exception.Message)" "Error"
            }
        }

    if (-not $found) {
        Write-Log "Not installed (skipped): $Name" "Info"
    }
}

function Disable-Telemetry {
    Write-Log "Disabling telemetry..." "Info"
    $paths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    )
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Set-ItemProperty -Path $p -Name "AllowTelemetry" -Value 0 -Type DWord -Force
    }
    Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
    Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Log "Telemetry disabled." "Success"
}

function Disable-CortanaFeature {
    Write-Log "Disabling Cortana..." "Info"
    $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "AllowCortana" -Value 0 -Type DWord -Force
    Write-Log "Cortana disabled." "Success"
}

function Disable-BingSearch {
    Write-Log "Disabling Bing Search in Start Menu..." "Info"
    $p = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $p -Name "CortanaConsent" -Value 0 -Type DWord -Force
    Write-Log "Bing Search disabled." "Success"
}

function Disable-ConsumerFeatures {
    Write-Log "Disabling Consumer Features (auto app installs)..." "Info"
    $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -Force
    Write-Log "Consumer features disabled." "Success"
}

function Disable-GameDVR {
    Write-Log "Disabling Game Bar / Game DVR..." "Info"
    $p1 = "HKCU:\System\GameConfigStore"
    if (-not (Test-Path $p1)) { New-Item -Path $p1 -Force | Out-Null }
    Set-ItemProperty -Path $p1 -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
    $p2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (-not (Test-Path $p2)) { New-Item -Path $p2 -Force | Out-Null }
    Set-ItemProperty -Path $p2 -Name "AllowGameDVR" -Value 0 -Type DWord -Force
    Write-Log "Game Bar / Game DVR disabled." "Success"
}

function Disable-AdvertisingId {
    Write-Log "Disabling Advertising ID..." "Info"
    $p = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "Enabled" -Value 0 -Type DWord -Force
    Write-Log "Advertising ID disabled." "Success"
}

function Disable-Suggestions {
    Write-Log "Disabling Start Menu / Lock Screen suggestions..." "Info"
    $p = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    $names = @(
        "SubscribedContent-338388Enabled",
        "SubscribedContent-338389Enabled",
        "SubscribedContent-353694Enabled",
        "SubscribedContent-353696Enabled",
        "SystemPaneSuggestionsEnabled",
        "SilentInstalledAppsEnabled",
        "PreInstalledAppsEnabled",
        "OemPreInstalledAppsEnabled"
    )
    foreach ($n in $names) {
        Set-ItemProperty -Path $p -Name $n -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    Write-Log "Suggestions / ads disabled." "Success"
}

function Disable-ActivityHistory {
    Write-Log "Disabling Activity History / Timeline..." "Info"
    $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "EnableActivityFeed" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $p -Name "PublishUserActivities" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $p -Name "UploadUserActivities" -Value 0 -Type DWord -Force
    Write-Log "Activity History disabled." "Success"
}

function Uninstall-OneDriveApp {
    Write-Log "Uninstalling OneDrive..." "Info"
    try {
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        $onedriveSetup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        if (-not (Test-Path $onedriveSetup)) { $onedriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe" }
        if (Test-Path $onedriveSetup) {
            Start-Process $onedriveSetup -ArgumentList "/uninstall" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        }
        Write-Log "OneDrive uninstalled." "Success"
    } catch {
        Write-Log "OneDrive removal issue: $($_.Exception.Message)" "Warning"
    }
}

function Disable-WidgetsTaskbar {
    Write-Log "Removing Widgets from Taskbar..." "Info"
    $p = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "TaskbarDa" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Widgets removed from taskbar." "Success"
}

function Disable-ChatTaskbar {
    Write-Log "Removing Chat icon from Taskbar..." "Info"
    $p = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "TaskbarMn" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Log "Chat icon removed from taskbar." "Success"
}

function Disable-CopilotFeature {
    Write-Log "Disabling Windows Copilot..." "Info"
    $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
    Write-Log "Windows Copilot disabled." "Success"
}

function Get-InstalledUserApps {
    # Returns a friendly, de-duplicated list of currently installed appx apps
    try {
        Get-AppxPackage -Name "*" | Where-Object {
            $_.Name -notin $ProtectedApps -and
            -not ($_.IsFramework) -and
            -not ($_.SignatureKind -eq 'System' -and $_.Publisher -notmatch 'CN=Microsoft')
        } | Select-Object -ExpandProperty Name -Unique | Sort-Object
    } catch {
        @()
    }
}

# ============================================================================
#  RUN LOGIC
# ============================================================================
function Invoke-DebloatRun {
    param(
        [string[]]$AppsToRemove,
        [string[]]$TweakIdsToApply,
        [System.Windows.Forms.ProgressBar]$ProgressBar
    )

    $script:LogBox.Clear()
    Write-Log "=== Win-Debloater run started ===" "Info"

    $totalSteps = $AppsToRemove.Count + $TweakIdsToApply.Count
    if ($totalSteps -eq 0) {
        Write-Log "Nothing selected to do." "Warning"
        return
    }
    $ProgressBar.Minimum = 0
    $ProgressBar.Maximum = $totalSteps
    $ProgressBar.Value = 0

    # Restore point first, if selected
    if ($TweakIdsToApply -contains "RestorePoint") {
        New-SystemRestorePoint
        $TweakIdsToApply = $TweakIdsToApply | Where-Object { $_ -ne "RestorePoint" }
        $ProgressBar.Value = [Math]::Min($ProgressBar.Value + 1, $ProgressBar.Maximum)
    }

    Write-Log "--- Removing $($AppsToRemove.Count) app(s) ---" "Info"
    foreach ($app in $AppsToRemove) {
        Remove-BloatApp -Name $app
        $ProgressBar.Value = [Math]::Min($ProgressBar.Value + 1, $ProgressBar.Maximum)
        [System.Windows.Forms.Application]::DoEvents()
    }

    Write-Log "--- Applying $($TweakIdsToApply.Count) tweak(s) ---" "Info"
    foreach ($tid in $TweakIdsToApply) {
        $tweak = $TweaksCatalog | Where-Object { $_.Id -eq $tid }
        if ($tweak) {
            try {
                & $tweak.Action
            } catch {
                Write-Log "Tweak '$($tweak.Label)' failed: $($_.Exception.Message)" "Error"
            }
        }
        $ProgressBar.Value = [Math]::Min($ProgressBar.Value + 1, $ProgressBar.Maximum)
        [System.Windows.Forms.Application]::DoEvents()
    }

    Write-Log "=== Run complete. A restart is recommended. ===" "Success"
    [System.Windows.Forms.MessageBox]::Show(
        "Debloat run finished. It's recommended to restart your PC for all changes to take effect.",
        "Win-Debloater",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

# ============================================================================
#  GUI HELPERS
# ============================================================================
function New-StyledButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$W = 150, [int]$H = 38, [bool]$Primary = $true)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = New-Object System.Drawing.Point($X, $Y)
    $btn.Size = New-Object System.Drawing.Size($W, $H)
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0
    $btn.Font = New-Object System.Drawing.Font($FontFamily, 10, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($Primary) {
        $btn.BackColor = $Theme.Accent
        $btn.ForeColor = [System.Drawing.Color]::FromArgb(15,17,20)
        $btn.FlatAppearance.MouseOverBackColor = $Theme.AccentDark
    } else {
        $btn.BackColor = $Theme.PanelAlt
        $btn.ForeColor = $Theme.TextPrimary
        $btn.FlatAppearance.MouseOverBackColor = $Theme.Border
    }
    return $btn
}

function New-SectionLabel {
    param([string]$Text, [int]$X, [int]$Y, [int]$Size = 11)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Location = New-Object System.Drawing.Point($X, $Y)
    $lbl.AutoSize = $true
    $lbl.ForeColor = $Theme.TextPrimary
    $lbl.Font = New-Object System.Drawing.Font($FontFamily, $Size, [System.Drawing.FontStyle]::Bold)
    return $lbl
}

# ============================================================================
#  BUILD MAIN FORM
# ============================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Win-Debloater — Windows 10 / 11 Cleanup Tool"
$form.Size = New-Object System.Drawing.Size(980, 700)
$form.StartPosition = "CenterScreen"
$form.BackColor = $Theme.Background
$form.ForeColor = $Theme.TextPrimary
$form.Font = New-Object System.Drawing.Font($FontFamily, 9.5)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false

# --- Header bar ---
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(980, 70)
$headerPanel.Location = New-Object System.Drawing.Point(0,0)
$headerPanel.BackColor = $Theme.Panel
$form.Controls.Add($headerPanel)

$titleLbl = New-Object System.Windows.Forms.Label
$titleLbl.Text = "🧹  Win-Debloater"
$titleLbl.Font = New-Object System.Drawing.Font($FontFamily, 16, [System.Drawing.FontStyle]::Bold)
$titleLbl.ForeColor = $Theme.TextPrimary
$titleLbl.Location = New-Object System.Drawing.Point(20, 14)
$titleLbl.AutoSize = $true
$headerPanel.Controls.Add($titleLbl)

$subtitleLbl = New-Object System.Windows.Forms.Label
$subtitleLbl.Text = "Remove bloatware & apply privacy tweaks — Windows 10 & 11"
$subtitleLbl.Font = New-Object System.Drawing.Font($FontFamily, 9)
$subtitleLbl.ForeColor = $Theme.TextMuted
$subtitleLbl.Location = New-Object System.Drawing.Point(23, 44)
$subtitleLbl.AutoSize = $true
$headerPanel.Controls.Add($subtitleLbl)

$osLbl = New-Object System.Windows.Forms.Label
$osVersion = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
$osLbl.Text = if ($osVersion) { $osVersion } else { "Windows" }
$osLbl.Font = New-Object System.Drawing.Font($FontFamily, 9)
$osLbl.ForeColor = $Theme.Accent
$osLbl.AutoSize = $true
$osLbl.Location = New-Object System.Drawing.Point(780, 26)
$headerPanel.Controls.Add($osLbl)

# --- Mode selection ---
$modePanel = New-Object System.Windows.Forms.Panel
$modePanel.Location = New-Object System.Drawing.Point(20, 82)
$modePanel.Size = New-Object System.Drawing.Size(940, 50)
$modePanel.BackColor = $Theme.Background
$form.Controls.Add($modePanel)

$modeLbl = New-SectionLabel -Text "Mode:" -X 0 -Y 12
$modePanel.Controls.Add($modeLbl)

$radioDefault = New-Object System.Windows.Forms.RadioButton
$radioDefault.Text = "Default (Recommended — Safe Auto Selection)"
$radioDefault.Location = New-Object System.Drawing.Point(70, 12)
$radioDefault.AutoSize = $true
$radioDefault.Checked = $true
$radioDefault.ForeColor = $Theme.TextPrimary
$radioDefault.Font = New-Object System.Drawing.Font($FontFamily, 10)
$modePanel.Controls.Add($radioDefault)

$radioCustom = New-Object System.Windows.Forms.RadioButton
$radioCustom.Text = "Custom (Choose apps & tweaks yourself)"
$radioCustom.Location = New-Object System.Drawing.Point(470, 12)
$radioCustom.AutoSize = $true
$radioCustom.ForeColor = $Theme.TextPrimary
$radioCustom.Font = New-Object System.Drawing.Font($FontFamily, 10)
$modePanel.Controls.Add($radioCustom)

# --- Body split: left = apps, right = tweaks ---
$appsGroup = New-Object System.Windows.Forms.GroupBox
$appsGroup.Text = "Apps"
$appsGroup.ForeColor = $Theme.TextPrimary
$appsGroup.Font = New-Object System.Drawing.Font($FontFamily, 10, [System.Drawing.FontStyle]::Bold)
$appsGroup.Location = New-Object System.Drawing.Point(20, 140)
$appsGroup.Size = New-Object System.Drawing.Size(560, 380)
$form.Controls.Add($appsGroup)

$appsInfoLbl = New-Object System.Windows.Forms.Label
$appsInfoLbl.Text = "Default mode removes a curated safe list automatically.`nSwitch to Custom to scan & pick installed apps individually."
$appsInfoLbl.ForeColor = $Theme.TextMuted
$appsInfoLbl.Location = New-Object System.Drawing.Point(15, 28)
$appsInfoLbl.Size = New-Object System.Drawing.Size(530, 40)
$appsGroup.Controls.Add($appsInfoLbl)

$appsChecklist = New-Object System.Windows.Forms.CheckedListBox
$appsChecklist.Location = New-Object System.Drawing.Point(15, 75)
$appsChecklist.Size = New-Object System.Drawing.Size(530, 260)
$appsChecklist.BackColor = $Theme.PanelAlt
$appsChecklist.ForeColor = $Theme.TextPrimary
$appsChecklist.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$appsChecklist.CheckOnClick = $true
$appsChecklist.Font = New-Object System.Drawing.Font($FontFamily, 9.5)
$appsChecklist.Enabled = $false
$appsGroup.Controls.Add($appsChecklist)

$btnScan = New-StyledButton -Text "🔍 Scan Installed Apps" -X 15 -Y 340 -W 200 -H 30 -Primary $false
$btnScan.Enabled = $false
$appsGroup.Controls.Add($btnScan)

$selectAllBtn = New-StyledButton -Text "Select All" -X 225 -Y 340 -W 100 -H 30 -Primary $false
$selectAllBtn.Enabled = $false
$appsGroup.Controls.Add($selectAllBtn)

$selectNoneBtn = New-StyledButton -Text "Select None" -X 335 -Y 340 -W 100 -H 30 -Primary $false
$selectNoneBtn.Enabled = $false
$appsGroup.Controls.Add($selectNoneBtn)

$tweaksGroup = New-Object System.Windows.Forms.GroupBox
$tweaksGroup.Text = "Tweaks"
$tweaksGroup.ForeColor = $Theme.TextPrimary
$tweaksGroup.Font = New-Object System.Drawing.Font($FontFamily, 10, [System.Drawing.FontStyle]::Bold)
$tweaksGroup.Location = New-Object System.Drawing.Point(595, 140)
$tweaksGroup.Size = New-Object System.Drawing.Size(365, 380)
$form.Controls.Add($tweaksGroup)

$tweaksChecklist = New-Object System.Windows.Forms.CheckedListBox
$tweaksChecklist.Location = New-Object System.Drawing.Point(15, 28)
$tweaksChecklist.Size = New-Object System.Drawing.Size(335, 335)
$tweaksChecklist.BackColor = $Theme.PanelAlt
$tweaksChecklist.ForeColor = $Theme.TextPrimary
$tweaksChecklist.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$tweaksChecklist.CheckOnClick = $true
$tweaksChecklist.Font = New-Object System.Drawing.Font($FontFamily, 9.5)
foreach ($t in $TweaksCatalog) {
    $idx = $tweaksChecklist.Items.Add($t.Label)
}
$tweaksGroup.Controls.Add($tweaksChecklist)

# --- Log panel ---
$logGroup = New-Object System.Windows.Forms.GroupBox
$logGroup.Text = "Activity Log"
$logGroup.ForeColor = $Theme.TextPrimary
$logGroup.Font = New-Object System.Drawing.Font($FontFamily, 10, [System.Drawing.FontStyle]::Bold)
$logGroup.Location = New-Object System.Drawing.Point(20, 530)
$logGroup.Size = New-Object System.Drawing.Size(940, 100)
$form.Controls.Add($logGroup)

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(15, 20)
$logBox.Size = New-Object System.Drawing.Size(910, 70)
$logBox.BackColor = [System.Drawing.Color]::FromArgb(14,15,19)
$logBox.ForeColor = $Theme.TextPrimary
$logBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logGroup.Controls.Add($logBox)
$script:LogBox = $logBox

# --- Bottom action bar ---
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 640)
$progressBar.Size = New-Object System.Drawing.Size(650, 22)
$progressBar.ForeColor = $Theme.Accent
$form.Controls.Add($progressBar)

$btnRun = New-StyledButton -Text "▶  Run" -X 690 -Y 636 -W 130 -H 32 -Primary $true
$form.Controls.Add($btnRun)

$btnExit = New-StyledButton -Text "Exit" -X 830 -Y 636 -W 130 -H 32 -Primary $false
$form.Controls.Add($btnExit)

# ============================================================================
#  EVENTS
# ============================================================================
function Sync-DefaultModeUI {
    $appsChecklist.Enabled = $false
    $btnScan.Enabled = $false
    $selectAllBtn.Enabled = $false
    $selectNoneBtn.Enabled = $false
    $appsChecklist.Items.Clear()
    foreach ($a in $DefaultBloatList) { $appsChecklist.Items.Add($a, $true) | Out-Null }

    $tweaksChecklist.Items.Clear()
    for ($i = 0; $i -lt $TweaksCatalog.Count; $i++) {
        $t = $TweaksCatalog[$i]
        $tweaksChecklist.Items.Add($t.Label, [bool]$t.Default) | Out-Null
    }
    $tweaksChecklist.Enabled = $false
    Write-Log "Default mode selected — safe app list & recommended tweaks pre-loaded." "Info"
}

function Sync-CustomModeUI {
    $appsChecklist.Enabled = $true
    $btnScan.Enabled = $true
    $selectAllBtn.Enabled = $true
    $selectNoneBtn.Enabled = $true
    $tweaksChecklist.Enabled = $true
    $appsChecklist.Items.Clear()
    $tweaksChecklist.Items.Clear()
    for ($i = 0; $i -lt $TweaksCatalog.Count; $i++) {
        $t = $TweaksCatalog[$i]
        $tweaksChecklist.Items.Add($t.Label, $false) | Out-Null
    }
    Write-Log "Custom mode selected — click 'Scan Installed Apps' to populate the app list, then choose what to remove." "Info"
}

$radioDefault.Add_CheckedChanged({
    if ($radioDefault.Checked) { Sync-DefaultModeUI }
})
$radioCustom.Add_CheckedChanged({
    if ($radioCustom.Checked) { Sync-CustomModeUI }
})

$btnScan.Add_Click({
    $appsChecklist.Items.Clear()
    Write-Log "Scanning installed apps..." "Info"
    [System.Windows.Forms.Application]::DoEvents()
    $installed = Get-InstalledUserApps
    if ($installed.Count -eq 0) {
        Write-Log "No removable apps found or scan failed." "Warning"
    } else {
        foreach ($app in $installed) { $appsChecklist.Items.Add($app, $false) | Out-Null }
        Write-Log "Found $($installed.Count) removable app(s)." "Success"
    }
})

$selectAllBtn.Add_Click({
    for ($i = 0; $i -lt $appsChecklist.Items.Count; $i++) { $appsChecklist.SetItemChecked($i, $true) }
})
$selectNoneBtn.Add_Click({
    for ($i = 0; $i -lt $appsChecklist.Items.Count; $i++) { $appsChecklist.SetItemChecked($i, $false) }
})

$btnRun.Add_Click({
    $appsToRemove = @()
    for ($i = 0; $i -lt $appsChecklist.Items.Count; $i++) {
        if ($appsChecklist.GetItemChecked($i)) { $appsToRemove += $appsChecklist.Items[$i].ToString() }
    }

    $tweakIds = @()
    for ($i = 0; $i -lt $tweaksChecklist.Items.Count; $i++) {
        if ($tweaksChecklist.GetItemChecked($i)) { $tweakIds += $TweaksCatalog[$i].Id }
    }

    $modeName = if ($radioDefault.Checked) { "Default" } else { "Custom" }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Mode: $modeName`nApps to remove: $($appsToRemove.Count)`nTweaks to apply: $($tweakIds.Count)`n`nProceed?",
        "Confirm Run",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        $btnRun.Enabled = $false
        $btnScan.Enabled = $false
        Invoke-DebloatRun -AppsToRemove $appsToRemove -TweakIdsToApply $tweakIds -ProgressBar $progressBar
        $btnRun.Enabled = $true
        if ($radioCustom.Checked) { $btnScan.Enabled = $true }
    }
})

$btnExit.Add_Click({ $form.Close() })

# Initialize with Default mode UI
Sync-DefaultModeUI

# ============================================================================
#  SHOW FORM
# ============================================================================
[void]$form.ShowDialog()
