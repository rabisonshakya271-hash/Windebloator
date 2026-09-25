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
#  ADDITIONAL PROFESSIONAL WINDOWS OPTIMIZATION / ISO BUILDER MODULES
#  Existing code above is preserved. New functionality is added separately.
# ============================================================================

$script:WinDebloatBackupRoot = Join-Path $env:ProgramData "Win-Debloater\Backups"
$script:WinDebloatPostSetupRoot = Join-Path $env:ProgramData "Win-Debloater\PostSetup"
$script:WinDebloatIsoRoot = Join-Path $env:USERPROFILE "Documents\Win-Debloater\ISO"

foreach ($folder in @(
    $script:WinDebloatBackupRoot,
    $script:WinDebloatPostSetupRoot,
    $script:WinDebloatIsoRoot
)) {
    try {
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }
    } catch {}
}

$script:SafeOptimizationServices = @(
    @{ Name="MapsBroker";       Description="Downloaded Maps Manager"; Safe=$true;  Risk="Safe"; Backup=$true },
    @{ Name="lfsvc";            Description="Geolocation Service"; Safe=$true;  Risk="Optional"; Backup=$true },
    @{ Name="RetailDemo";       Description="Retail Demo Service"; Safe=$true;  Risk="Safe"; Backup=$true },
    @{ Name="Fax";              Description="Fax service"; Safe=$true;  Risk="Optional"; Backup=$true },
    @{ Name="WerSvc";           Description="Windows Error Reporting"; Safe=$false; Risk="Optional"; Backup=$true },
    @{ Name="WSearch";          Description="Windows Search indexing"; Safe=$false; Risk="Advanced"; Backup=$true },
    @{ Name="SysMain";          Description="SysMain / Superfetch"; Safe=$false; Risk="Advanced"; Backup=$true }
)

$script:KnownCriticalServices = @(
    "RpcSs",
    "DcomLaunch",
    "RpcEptMapper",
    "Winmgmt",
    "EventLog",
    "PlugPlay",
    "Power",
    "ProfSvc",
    "SamSs",
    "Schedule",
    "Spooler",
    "TrustedInstaller",
    "wuauserv",
    "BITS",
    "CryptSvc",
    "WinDefend",
    "SecurityHealthService",
    "MpsSvc",
    "Dhcp",
    "Dnscache",
    "LanmanWorkstation",
    "LanmanServer",
    "LSM",
    "TermService"
)

function New-WinDebloaterBackupFolder {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $path = Join-Path $script:WinDebloatBackupRoot $stamp

    try {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        return $path
    } catch {
        return $null
    }
}

function Get-StartupItemsSafe {
    $items = @()

    $locations = @(
        @{ Name="HKCU Startup"; Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Scope="Current User" },
        @{ Name="HKLM Startup"; Path="HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"; Scope="All Users" },
        @{ Name="HKLM Startup WOW64"; Path="HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; Scope="All Users" }
    )

    foreach ($location in $locations) {
        try {
            if (Test-Path $location.Path) {
                $props = Get-ItemProperty -Path $location.Path -ErrorAction SilentlyContinue
                foreach ($prop in $props.PSObject.Properties) {
                    if ($prop.Name -notmatch '^PS') {
                        $items += [PSCustomObject]@{
                            Name = $prop.Name
                            Command = [string]$prop.Value
                            Status = "Enabled"
                            Scope = $location.Scope
                            Location = $location.Name
                            RegistryPath = $location.Path
                            ValueName = $prop.Name
                        }
                    }
                }
            }
        } catch {}
    }

    $startupFolder = [Environment]::GetFolderPath("Startup")

    if (Test-Path $startupFolder) {
        Get-ChildItem -Path $startupFolder -File -ErrorAction SilentlyContinue | ForEach-Object {
            $items += [PSCustomObject]@{
                Name = $_.Name
                Command = $_.FullName
                Status = "Enabled"
                Scope = "Current User"
                Location = "Startup Folder"
                RegistryPath = ""
                ValueName = ""
            }
        }
    }

    return $items
}

function Disable-WinDebloaterStartupItem {
    param([Parameter(Mandatory=$true)]$Item)

    $backup = New-WinDebloaterBackupFolder
    if (-not $backup) {
        Write-Log "Could not create startup backup." "Error"
        return
    }

    try {
        if ($Item.RegistryPath -and $Item.ValueName) {
            $backupFile = Join-Path $backup "Startup.reg"
            & reg.exe export $Item.RegistryPath $backupFile /y 2>$null | Out-Null

            $disabledPath = $Item.RegistryPath + "\Win-DebloaterDisabled"

            if (-not (Test-Path $disabledPath)) {
                New-Item -Path $disabledPath -Force | Out-Null
            }

            $value = Get-ItemPropertyValue -Path $Item.RegistryPath -Name $Item.ValueName -ErrorAction Stop
            New-ItemProperty -Path $disabledPath -Name $Item.ValueName -Value $value -PropertyType String -Force | Out-Null
            Remove-ItemProperty -Path $Item.RegistryPath -Name $Item.ValueName -ErrorAction Stop

            Write-Log "Startup item disabled: $($Item.Name)" "Success"
        } else {
            Write-Log "This startup entry is not registry-based and was not modified." "Warning"
        }
    } catch {
        Write-Log "Could not disable startup item '$($Item.Name)': $($_.Exception.Message)" "Error"
    }
}

function Restore-WinDebloaterStartupItem {
    param([Parameter(Mandatory=$true)]$Item)

    try {
        if ($Item.RegistryPath -and $Item.ValueName) {
            $disabledPath = $Item.RegistryPath + "\Win-DebloaterDisabled"

            if (Test-Path $disabledPath) {
                $value = Get-ItemPropertyValue -Path $disabledPath -Name $Item.ValueName -ErrorAction Stop
                New-ItemProperty -Path $Item.RegistryPath -Name $Item.ValueName -Value $value -PropertyType String -Force | Out-Null
                Remove-ItemProperty -Path $disabledPath -Name $Item.ValueName -ErrorAction SilentlyContinue

                Write-Log "Startup item restored: $($Item.Name)" "Success"
            } else {
                Write-Log "No Win-Debloater backup found for: $($Item.Name)" "Warning"
            }
        }
    } catch {
        Write-Log "Could not restore startup item '$($Item.Name)': $($_.Exception.Message)" "Error"
    }
}

function Get-WinDebloaterServices {
    $services = @()

    Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
        Sort-Object DisplayName |
        ForEach-Object {

            $known = $script:SafeOptimizationServices | Where-Object { $_.Name -eq $_.Name }

            $recommendation = "Leave unchanged"
            $risk = "System / Unknown"

            $definition = $script:SafeOptimizationServices | Where-Object { $_.Name -eq $PSItem.Name }

            if ($definition) {
                $recommendation = if ($definition.Safe) { "Safe / Optional" } else { "Advanced / Review" }
                $risk = $definition.Risk
            }

            if ($script:KnownCriticalServices -contains $PSItem.Name) {
                $recommendation = "Critical — Do Not Disable"
                $risk = "Critical"
            }

            $services += [PSCustomObject]@{
                Name = $PSItem.Name
                DisplayName = $PSItem.DisplayName
                Status = $PSItem.State
                StartType = $PSItem.StartMode
                Recommendation = $recommendation
                Risk = $risk
                CanModify = ($script:KnownCriticalServices -notcontains $PSItem.Name)
            }
        }

    return $services
}

function Backup-WinDebloaterService {
    param([string]$ServiceName)

    try {
        $service = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
        $backup = New-WinDebloaterBackupFolder

        if ($backup) {
            $file = Join-Path $backup "services.json"
            $existing = @()

            if (Test-Path $file) {
                try {
                    $existing = @(Get-Content $file -Raw | ConvertFrom-Json)
                } catch {}
            }

            $entry = [PSCustomObject]@{
                Name = $service.Name
                StartMode = $service.StartMode
                State = $service.State
                Time = (Get-Date).ToString("o")
            }

            @($existing + $entry) | ConvertTo-Json -Depth 5 | Set-Content $file -Encoding UTF8
        }
    } catch {}
}

function Set-WinDebloaterServiceDisabled {
    param([string]$ServiceName)

    if ($script:KnownCriticalServices -contains $ServiceName) {
        Write-Log "Blocked: critical Windows service '$ServiceName' cannot be disabled by this tool." "Warning"
        return
    }

    $definition = $script:SafeOptimizationServices | Where-Object { $_.Name -eq $ServiceName }

    if (-not $definition) {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "This service is not in the safe optimization list.`n`nOnly disable it if you understand its purpose.`n`nContinue?",
            "Advanced Service Operation",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }
    }

    try {
        Backup-WinDebloaterService -ServiceName $ServiceName
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
        Write-Log "Service disabled: $ServiceName" "Success"
    } catch {
        Write-Log "Could not disable service '$ServiceName': $($_.Exception.Message)" "Error"
    }
}

function Restore-WinDebloaterService {
    param([string]$ServiceName)

    try {
        $service = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop

        $startMode = "Manual"

        if ($ServiceName -eq "WSearch") {
            $startMode = "Automatic"
        } elseif ($ServiceName -eq "SysMain") {
            $startMode = "Automatic"
        }

        Set-Service -Name $ServiceName -StartupType $startMode -ErrorAction Stop
        Write-Log "Service restored to $startMode: $ServiceName" "Success"
    } catch {
        Write-Log "Could not restore service '$ServiceName': $($_.Exception.Message)" "Error"
    }
}

function Clear-WinDebloaterTempFiles {
    Write-Log "Cleaning temporary files..." "Info"

    $targets = @(
        $env:TEMP,
        "$env:SystemRoot\Temp"
    )

    $removed = 0

    foreach ($target in $targets) {
        if (Test-Path $target) {
            Get-ChildItem -Path $target -Force -ErrorAction SilentlyContinue |
                ForEach-Object {
                    try {
                        Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop
                        $removed++
                    } catch {}
                }
        }
    }

    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    } catch {}

    Write-Log "Temporary cleanup completed. Removed $removed item(s)." "Success"
}

function Set-WinDebloaterVisualPerformance {
    param(
        [bool]$DisableAnimations = $true,
        [bool]$DisableFades = $true,
        [bool]$KeepTransparency = $true
    )

    try {
        $p = "HKCU:\Control Panel\Desktop\WindowMetrics"
        if (-not (Test-Path $p)) {
            New-Item -Path $p -Force | Out-Null
        }

        $p2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"

        if (-not (Test-Path $p2)) {
            New-Item -Path $p2 -Force | Out-Null
        }

        if ($DisableAnimations) {
            Set-ItemProperty -Path $p2 -Name "VisualFXSetting" -Value 3 -Type DWord -Force
        }

        $p3 = "HKCU:\Control Panel\Desktop"
        if (-not (Test-Path $p3)) {
            New-Item -Path $p3 -Force | Out-Null
        }

        if ($DisableFades) {
            Set-ItemProperty -Path $p3 -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force -ErrorAction SilentlyContinue
        }

        if ($KeepTransparency) {
            $p4 = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            if (-not (Test-Path $p4)) {
                New-Item -Path $p4 -Force | Out-Null
            }

            Set-ItemProperty -Path $p4 -Name "EnableTransparency" -Value 1 -Type DWord -Force
        }

        Write-Log "Windows visual performance settings applied. Transparency preference preserved." "Success"
    } catch {
        Write-Log "Visual performance configuration failed: $($_.Exception.Message)" "Error"
    }
}

function Set-WinDebloaterLowEndOptimization {
    Write-Log "Applying safe low-end PC optimizations..." "Info"

    try {
        Set-WinDebloaterVisualPerformance -DisableAnimations $true -DisableFades $true -KeepTransparency $true

        $temp = Join-Path $env:TEMP "Win-Debloater"
        if (-not (Test-Path $temp)) {
            New-Item -ItemType Directory -Path $temp -Force | Out-Null
        }

        Write-Log "Low-end optimization profile applied." "Success"
    } catch {
        Write-Log "Low-end optimization encountered an issue: $($_.Exception.Message)" "Warning"
    }
}

function Get-WinDebloaterScheduledTasks {
    $tasks = @()

    try {
        Get-ScheduledTask -ErrorAction Stop |
            Sort-Object TaskPath,TaskName |
            ForEach-Object {

                $risk = "Review"
                $recommendation = "Leave unchanged"

                if ($_.TaskPath -match "\\Microsoft\\Windows\\(Application Experience|Customer Experience Improvement Program|Maps|Feedback|Windows Error Reporting)\\") {
                    $risk = "Optional"
                    $recommendation = "Optional / Review"
                }

                if ($_.TaskPath -match "\\Microsoft\\Windows\\UpdateOrchestrator|\\Microsoft\\Windows\\WindowsUpdate") {
                    $risk = "Critical"
                    $recommendation = "Do Not Disable"
                }

                $tasks += [PSCustomObject]@{
                    TaskName = $_.TaskName
                    TaskPath = $_.TaskPath
                    State = [string]$_.State
                    Recommendation = $recommendation
                    Risk = $risk
                }
            }
    } catch {}

    return $tasks
}

function Disable-WinDebloaterScheduledTask {
    param(
        [string]$TaskName,
        [string]$TaskPath,
        [string]$Risk
    )

    if ($Risk -eq "Critical") {
        Write-Log "Blocked: critical scheduled task cannot be disabled." "Warning"
        return
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        "Disable scheduled task:`n`n$TaskPath$TaskName`n`nThis action is reversible. Continue?",
        "Confirm Scheduled Task Change",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    try {
        $backup = New-WinDebloaterBackupFolder

        if ($backup) {
            $safeName = ($TaskName -replace '[\\/:*?"<>|]','_')
            Export-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue |
                Set-Content -Path (Join-Path $backup "$safeName.xml") -Encoding UTF8
        }

        Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop | Out-Null
        Write-Log "Scheduled task disabled: $TaskPath$TaskName" "Success"
    } catch {
        Write-Log "Could not disable scheduled task: $($_.Exception.Message)" "Error"
    }
}

function Restore-WinDebloaterScheduledTask {
    param(
        [string]$TaskName,
        [string]$TaskPath
    )

    try {
        Enable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop | Out-Null
        Write-Log "Scheduled task enabled: $TaskPath$TaskName" "Success"
    } catch {
        Write-Log "Could not enable scheduled task: $($_.Exception.Message)" "Error"
    }
}

function Get-WinDebloaterDiskInfo {
    try {
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
            Select-Object DeviceID,
                @{Name="SizeGB";Expression={[math]::Round($_.Size / 1GB,2)}},
                @{Name="FreeGB";Expression={[math]::Round($_.FreeSpace / 1GB,2)}}
    } catch {
        @()
    }
}

function Get-WinDebloaterSystemSummary {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Windows = $os.Caption
        Version = $os.Version
        Build = $os.BuildNumber
        CPU = $cpu.Name
        RAMGB = [math]::Round($computer.TotalPhysicalMemory / 1GB,2)
    }
}

# ============================================================================ 
#  ISO BUILDER DATA / FUNCTIONS
# ============================================================================

$script:IsoConfig = [ordered]@{
    SourceImage = ""
    MountDirectory = ""
    OutputISO = ""
    Architecture = "x64"
    Edition = ""
    RemoveApps = @()
    RemoveComponents = @()
    OptimizationProfile = "Balanced"
    PostSetupActions = @()
    AddedApplications = @()
}

$script:IsoSafeApps = @(
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal",
    "Microsoft.People",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.XboxApp",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Clipchamp.Clipchamp",
    "Microsoft.GamingApp"
)

$script:IsoAdvancedComponents = @(
    "Internet Explorer",
    "Windows Media Player",
    "Work Folders Client",
    "Printing Foundation",
    "XPS Viewer",
    "Fax and Scan",
    "PowerShell ISE",
    "SMB Direct"
)

function Select-WinDebloaterIsoSource {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Windows ISO (*.iso)|*.iso|All files (*.*)|*.*"
    $dialog.Title = "Select Windows 10 / 11 ISO"

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:IsoConfig.SourceImage = $dialog.FileName
        return $dialog.FileName
    }

    return $null
}

function Get-WinDebloaterIsoImages {
    param([string]$ImagePath)

    $results = @()

    if (-not (Test-Path $ImagePath)) {
        return $results
    }

    try {
        $mount = Mount-DiskImage -ImagePath $ImagePath -PassThru -ErrorAction Stop
        $drive = ($mount | Get-Volume).DriveLetter

        if ($drive) {
            $sources = "${drive}:\sources\install.wim"
            if (-not (Test-Path $sources)) {
                $sources = "${drive}:\sources\install.esd"
            }

            if (Test-Path $sources) {
                Get-WindowsImage -ImagePath $sources -ErrorAction Stop |
                    ForEach-Object {
                        $results += [PSCustomObject]@{
                            Index = $_.ImageIndex
                            Name = $_.ImageName
                            Description = $_.Description
                            SizeGB = [math]::Round($_.ImageSize / 1GB,2)
                        }
                    }
            }
        }

        Dismount-DiskImage -ImagePath $ImagePath -ErrorAction SilentlyContinue
    } catch {}

    return $results
}

function New-WinDebloaterIsoWorkingDirectory {
    param([string]$BasePath)

    if (-not $BasePath) {
        $BasePath = Join-Path $env:TEMP "Win-Debloater-ISO"
    }

    try {
        if (-not (Test-Path $BasePath)) {
            New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
        }

        $script:IsoConfig.MountDirectory = $BasePath
        return $BasePath
    } catch {
        return $null
    }
}

function Invoke-WinDebloaterIsoBuild {
    param(
        [string]$SourceISO,
        [string]$OutputISO,
        [int]$ImageIndex,
        [string]$Profile
    )

    if (-not $SourceISO -or -not (Test-Path $SourceISO)) {
        Write-Log "ISO Builder: source ISO not found." "Error"
        return $false
    }

    if (-not $OutputISO) {
        Write-Log "ISO Builder: output path was not selected." "Error"
        return $false
    }

    $confirmation = [System.Windows.Forms.MessageBox]::Show(
        "ISO creation can require significant disk space and may take time.`n`nSource:`n$SourceISO`n`nOutput:`n$OutputISO`n`nProfile:`n$Profile`n`nContinue?",
        "Confirm ISO Build",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($confirmation -ne [System.Windows.Forms.DialogResult]::Yes) {
        return $false
    }

    try {
        Write-Log "ISO Builder started." "Info"
        Write-Log "Profile: $Profile" "Info"

        $work = New-WinDebloaterIsoWorkingDirectory -BasePath (
            Join-Path $env:TEMP ("Win-Debloater-ISO-" + (Get-Date -Format "yyyyMMddHHmmss"))
        )

        if (-not $work) {
            throw "Could not create ISO working directory."
        }

        $mountDir = Join-Path $work "Mount"
        $extractDir = Join-Path $work "ISO"

        New-Item -ItemType Directory -Path $mountDir -Force | Out-Null
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

        Write-Log "Mounting source ISO..." "Info"

        $disk = Mount-DiskImage -ImagePath $SourceISO -PassThru -ErrorAction Stop
        $volume = $disk | Get-Volume
        $drive = $volume.DriveLetter

        if (-not $drive) {
            throw "Could not determine mounted ISO drive."
        }

        Write-Log "Copying ISO files to working directory..." "Info"
        Copy-Item -Path "${drive}:\*" -Destination $extractDir -Recurse -Force -ErrorAction Stop

        Dismount-DiskImage -ImagePath $SourceISO -ErrorAction SilentlyContinue

        $installImage = Join-Path $extractDir "sources\install.wim"
        if (-not (Test-Path $installImage)) {
            $installImage = Join-Path $extractDir "sources\install.esd"
        }

        if (-not (Test-Path $installImage)) {
            throw "install.wim or install.esd was not found."
        }

        Write-Log "Preparing Windows image index $ImageIndex..." "Info"

        if (-not $ImageIndex) {
            $ImageIndex = 1
        }

        Mount-WindowsImage -ImagePath $installImage -Index $ImageIndex -Path $mountDir -ReadOnly:$false -ErrorAction Stop

        if ($Profile -eq "Low-End Safe") {
            Write-Log "Applying Low-End Safe image profile..." "Info"

            foreach ($app in $script:IsoSafeApps) {
                try {
                    Get-AppxProvisionedPackage -Path $mountDir -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -like "*$app*" } |
                        ForEach-Object {
                            Remove-AppxProvisionedPackage -Path $mountDir -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
                        }
                } catch {}
            }
        }

        if ($Profile -eq "Balanced") {
            Write-Log "Applying Balanced image profile..." "Info"
        }

        if ($Profile -eq "Advanced") {
            Write-Log "Advanced profile selected. Component removal remains explicitly controlled by the user." "Warning"
        }

        if ($script:IsoConfig.RemoveApps.Count -gt 0) {
            foreach ($app in $script:IsoConfig.RemoveApps) {
                try {
                    Get-AppxProvisionedPackage -Path $mountDir -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -like "*$app*" } |
                        ForEach-Object {
                            Remove-AppxProvisionedPackage -Path $mountDir -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
                        }

                    Write-Log "ISO application removal processed: $app" "Success"
                } catch {
                    Write-Log "ISO application removal failed: $app" "Warning"
                }
            }
        }

        Write-Log "Saving customized Windows image..." "Info"
        Dismount-WindowsImage -Path $mountDir -Save -ErrorAction Stop

        Write-Log "Creating customized ISO..." "Info"

        $oscdimg = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"

        if (-not (Test-Path $oscdimg)) {
            $oscdimg = Join-Path $env:ProgramFiles "Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
        }

        if (-not (Test-Path $oscdimg)) {
            Write-Log "oscdimg.exe was not found. Install Windows ADK Deployment Tools to create bootable ISO files." "Error"
            return $false
        }

        $bootData = "-bootdata:2#p0,e,b`"$extractDir\boot\etfsboot.com`"#pEF,e,b`"$extractDir\efi\microsoft\boot\efisys.bin`""

        & $oscdimg -m -o -u2 -udfver102 $bootData $extractDir $OutputISO

        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputISO)) {
            Write-Log "Customized ISO created successfully." "Success"
            return $true
        }

        Write-Log "ISO creation failed with exit code $LASTEXITCODE." "Error"
        return $false

    } catch {
        Write-Log "ISO Builder error: $($_.Exception.Message)" "Error"

        try {
            if (Test-Path $script:IsoConfig.MountDirectory) {
                Dismount-WindowsImage -Path $script:IsoConfig.MountDirectory -Discard -ErrorAction SilentlyContinue
            }
        } catch {}

        return $false
    }
}

# ============================================================================ 
#  POST SETUP
# ============================================================================

function Add-WinDebloaterPostSetupAction {
    param(
        [string]$Type,
        [string]$Path,
        [string]$Arguments,
        [string]$Stage = "After Login",
        [bool]$Silent = $false,
        [bool]$RunOnce = $true,
        [int]$Order = 0
    )

    if (-not $Path) {
        return
    }

    $action = [PSCustomObject]@{
        Id = [guid]::NewGuid().ToString()
        Type = $Type
        Path = $Path
        Arguments = $Arguments
        Stage = $Stage
        Silent = $Silent
        RunOnce = $RunOnce
        Order = $Order
        Enabled = $true
    }

    $script:IsoConfig.PostSetupActions += $action

    Write-Log "Post Setup action added: $Type - $Path" "Success"
}

function Remove-WinDebloaterPostSetupAction {
    param([string]$Id)

    $script:IsoConfig.PostSetupActions = @(
        $script:IsoConfig.PostSetupActions |
            Where-Object { $_.Id -ne $Id }
    )
}

function Export-WinDebloaterPostSetupFiles {
    param([string]$DestinationRoot)

    if (-not $DestinationRoot) {
        return
    }

    try {
        $postDir = Join-Path $DestinationRoot "Win-Debloater-PostSetup"
        New-Item -ItemType Directory -Path $postDir -Force | Out-Null

        $actions = @(
            $script:IsoConfig.PostSetupActions |
                Where-Object { $_.Enabled } |
                Sort-Object Order
        )

        $manifest = Join-Path $postDir "PostSetup.json"
        $actions | ConvertTo-Json -Depth 10 | Set-Content $manifest -Encoding UTF8

        $runner = @'
$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifest = Join-Path $root "PostSetup.json"

if (-not (Test-Path $manifest)) {
    exit 0
}

$actions = @(Get-Content $manifest -Raw | ConvertFrom-Json)

foreach ($action in ($actions | Sort-Object Order)) {

    if (-not $action.Enabled) {
        continue
    }

    try {

        if ($action.Type -eq "PowerShell") {
            if ($action.RunOnce) {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $action.Path $action.Arguments
            } else {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $action.Path $action.Arguments
            }
        }

        elseif ($action.Type -eq "EXE") {
            $args = [string]$action.Arguments

            if ($action.Silent) {
                Start-Process -FilePath $action.Path -ArgumentList $args -Wait -WindowStyle Hidden
            } else {
                Start-Process -FilePath $action.Path -ArgumentList $args -Wait
            }
        }

        elseif ($action.Type -eq "MSI") {
            $args = "/i `"$($action.Path)`" /qn /norestart"

            if (-not $action.Silent) {
                $args = "/i `"$($action.Path)`" /passive /norestart"
            }

            Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait
        }

        elseif ($action.Type -eq "BAT" -or $action.Type -eq "CMD") {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($action.Path)`"" -Wait
        }

    } catch {}
}
'@

        Set-Content -Path (Join-Path $postDir "Run-PostSetup.ps1") -Value $runner -Encoding UTF8

        Write-Log "Post Setup package generated." "Success"
    } catch {
        Write-Log "Post Setup export failed: $($_.Exception.Message)" "Error"
    }
}

# ============================================================================ 
#  PROFESSIONAL UI HELPERS
# ============================================================================

function New-ProfessionalForm {
    param(
        [string]$Title,
        [int]$Width = 1100,
        [int]$Height = 720
    )

    $f = New-Object System.Windows.Forms.Form
    $f.Text = $Title
    $f.Size = New-Object System.Drawing.Size($Width,$Height)
    $f.StartPosition = "CenterParent"
    $f.BackColor = $Theme.Background
    $f.ForeColor = $Theme.TextPrimary
    $f.Font = New-Object System.Drawing.Font($FontFamily,9.5)
    $f.MinimizeBox = $true
    $f.MaximizeBox = $false

    return $f
}

function New-ProfessionalHeader {
    param(
        [System.Windows.Forms.Form]$TargetForm,
        [string]$Title,
        [string]$Subtitle
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(0,0)
    $panel.Size = New-Object System.Drawing.Size($TargetForm.ClientSize.Width,76)
    $panel.BackColor = $Theme.Panel
    $TargetForm.Controls.Add($panel)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = $Title
    $title.Location = New-Object System.Drawing.Point(24,14)
    $title.AutoSize = $true
    $title.Font = New-Object System.Drawing.Font($FontFamily,17,[System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $Theme.TextPrimary
    $panel.Controls.Add($title)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = $Subtitle
    $sub.Location = New-Object System.Drawing.Point(27,45)
    $sub.AutoSize = $true
    $sub.Font = New-Object System.Drawing.Font($FontFamily,9)
    $sub.ForeColor = $Theme.TextMuted
    $panel.Controls.Add($sub)

    return $panel
}

function New-ProfessionalListView {
    param(
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H
    )

    $lv = New-Object System.Windows.Forms.ListView
    $lv.Location = New-Object System.Drawing.Point($X,$Y)
    $lv.Size = New-Object System.Drawing.Size($W,$H)
    $lv.View = [System.Windows.Forms.View]::Details
    $lv.FullRowSelect = $true
    $lv.GridLines = $true
    $lv.MultiSelect = $false
    $lv.HideSelection = $false
    $lv.BackColor = $Theme.PanelAlt
    $lv.ForeColor = $Theme.TextPrimary
    $lv.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $lv.Font = New-Object System.Drawing.Font($FontFamily,9)
    return $lv
}

# ============================================================================ 
#  WINDOWS OPTIMIZATION WINDOW
# ============================================================================

function Show-WindowsOptimizationWindow {

    $f = New-ProfessionalForm -Title "Win-Debloater — Windows Optimization" -Width 1180 -Height 760
    New-ProfessionalHeader -TargetForm $f -Title "Windows Optimization" -Subtitle "Safe, reversible optimization tools for Windows 10 and Windows 11"

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Location = New-Object System.Drawing.Point(18,92)
    $tabs.Size = New-Object System.Drawing.Size(1140,585)
    $tabs.Font = New-Object System.Drawing.Font($FontFamily,10)
    $f.Controls.Add($tabs)

    # ------------------------------------------------------------------------
    # Startup
    # ------------------------------------------------------------------------

    $startupPage = New-Object System.Windows.Forms.TabPage
    $startupPage.Text = "Startup Apps"
    $startupPage.BackColor = $Theme.Background
    $tabs.TabPages.Add($startupPage)

    $startupInfo = New-Object System.Windows.Forms.Label
    $startupInfo.Text = "Review programs that start with Windows. Registry-based entries can be disabled and restored."
    $startupInfo.Location = New-Object System.Drawing.Point(18,18)
    $startupInfo.AutoSize = $true
    $startupInfo.ForeColor = $Theme.TextMuted
    $startupPage.Controls.Add($startupInfo)

    $startupList = New-ProfessionalListView -X 18 -Y 52 -W 1090 -H 410
    [void]$startupList.Columns.Add("Name",230)
    [void]$startupList.Columns.Add("Status",100)
    [void]$startupList.Columns.Add("Scope",120)
    [void]$startupList.Columns.Add("Location",170)
    [void]$startupList.Columns.Add("Command",450)
    $startupPage.Controls.Add($startupList)

    $startupRefresh = New-StyledButton -Text "Refresh" -X 18 -Y 480 -W 110 -H 34 -Primary $false
    $startupDisable = New-StyledButton -Text "Disable Selected" -X 138 -Y 480 -W 155 -H 34 -Primary $true
    $startupRestore = New-StyledButton -Text "Restore Selected" -X 303 -Y 480 -W 150 -H 34 -Primary $false
    $startupPage.Controls.Add($startupRefresh)
    $startupPage.Controls.Add($startupDisable)
    $startupPage.Controls.Add($startupRestore)

    $script:StartupData = @()

    $loadStartup = {
        $startupList.Items.Clear()
        $script:StartupData = @(Get-StartupItemsSafe)

        foreach ($item in $script:StartupData) {
            $row = New-Object System.Windows.Forms.ListViewItem($item.Name)
            [void]$row.SubItems.Add($item.Status)
            [void]$row.SubItems.Add($item.Scope)
            [void]$row.SubItems.Add($item.Location)
            [void]$row.SubItems.Add($item.Command)
            $row.Tag = $item
            [void]$startupList.Items.Add($row)
        }
    }

    $startupRefresh.Add_Click($loadStartup)

    $startupDisable.Add_Click({
        if ($startupList.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Select a startup application first.",
                "Startup Apps",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        $item = $startupList.SelectedItems[0].Tag

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Disable this startup application?`n`n$($item.Name)`n`nA backup will be created when possible.",
            "Confirm Startup Change",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            Disable-WinDebloaterStartupItem -Item $item
            & $loadStartup
        }
    })

    $startupRestore.Add_Click({
        if ($startupList.SelectedItems.Count -eq 0) {
            return
        }

        Restore-WinDebloaterStartupItem -Item $startupList.SelectedItems[0].Tag
        & $loadStartup
    })

    & $loadStartup

    # ------------------------------------------------------------------------
    # Services
    # ------------------------------------------------------------------------

    $servicePage = New-Object System.Windows.Forms.TabPage
    $servicePage.Text = "Windows Services"
    $servicePage.BackColor = $Theme.Background
    $tabs.TabPages.Add($servicePage)

    $serviceInfo = New-Object System.Windows.Forms.Label
    $serviceInfo.Text = "Only services identified as optional are presented as safe candidates. Critical services are protected."
    $serviceInfo.Location = New-Object System.Drawing.Point(18,18)
    $serviceInfo.AutoSize = $true
    $serviceInfo.ForeColor = $Theme.TextMuted
    $servicePage.Controls.Add($serviceInfo)

    $serviceList = New-ProfessionalListView -X 18 -Y 52 -W 1090 -H 410
    [void]$serviceList.Columns.Add("Service",150)
    [void]$serviceList.Columns.Add("Display Name",260)
    [void]$serviceList.Columns.Add("Status",90)
    [void]$serviceList.Columns.Add("Startup",100)
    [void]$serviceList.Columns.Add("Recommendation",190)
    [void]$serviceList.Columns.Add("Risk",100)
    $servicePage.Controls.Add($serviceList)

    $serviceRefresh = New-StyledButton -Text "Refresh" -X 18 -Y 480 -W 110 -H 34 -Primary $false
    $serviceDisable = New-StyledButton -Text "Disable Selected" -X 138 -Y 480 -W 155 -H 34 -Primary $true
    $serviceRestore = New-StyledButton -Text "Restore Selected" -X 303 -Y 480 -W 150 -H 34 -Primary $false
    $servicePage.Controls.Add($serviceRefresh)
    $servicePage.Controls.Add($serviceDisable)
    $servicePage.Controls.Add($serviceRestore)

    $script:ServiceData = @()

    $loadServices = {
        $serviceList.Items.Clear()
        $script:ServiceData = @(Get-WinDebloaterServices)

        foreach ($service in $script:ServiceData) {
            $row = New-Object System.Windows.Forms.ListViewItem($service.Name)
            [void]$row.SubItems.Add($service.DisplayName)
            [void]$row.SubItems.Add($service.Status)
            [void]$row.SubItems.Add($service.StartType)
            [void]$row.SubItems.Add($service.Recommendation)
            [void]$row.SubItems.Add($service.Risk)
            $row.Tag = $service
            [void]$serviceList.Items.Add($row)
        }
    }

    $serviceRefresh.Add_Click($loadServices)

    $serviceDisable.Add_Click({
        if ($serviceList.SelectedItems.Count -eq 0) {
            return
        }

        $service = $serviceList.SelectedItems[0].Tag

        if (-not $service.CanModify) {
            [System.Windows.Forms.MessageBox]::Show(
                "This service is protected because it is considered critical to Windows functionality.",
                "Protected Service",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        Set-WinDebloaterServiceDisabled -ServiceName $service.Name
        & $loadServices
    })

    $serviceRestore.Add_Click({
        if ($serviceList.SelectedItems.Count -eq 0) {
            return
        }

        Restore-WinDebloaterService -ServiceName $serviceList.SelectedItems[0].Tag.Name
        & $loadServices
    })

    & $loadServices

    # ------------------------------------------------------------------------
    # Scheduled Tasks
    # ------------------------------------------------------------------------

    $taskPage = New-Object System.Windows.Forms.TabPage
    $taskPage.Text = "Scheduled Tasks"
    $taskPage.BackColor = $Theme.Background
    $tabs.TabPages.Add($taskPage)

    $taskInfo = New-Object System.Windows.Forms.Label
    $taskInfo.Text = "Review optional scheduled tasks. Windows Update and other critical task paths are protected."
    $taskInfo.Location = New-Object System.Drawing.Point(18,18)
    $taskInfo.AutoSize = $true
    $taskInfo.ForeColor = $Theme.TextMuted
    $taskPage.Controls.Add($taskInfo)

    $taskList = New-ProfessionalListView -X 18 -Y 52 -W 1090 -H 410
    [void]$taskList.Columns.Add("Task Name",300)
    [void]$taskList.Columns.Add("Task Path",390)
    [void]$taskList.Columns.Add("State",100)
    [void]$taskList.Columns.Add("Recommendation",180)
    [void]$taskList.Columns.Add("Risk",100)
    $taskPage.Controls.Add($taskList)

    $taskRefresh = New-StyledButton -Text "Refresh" -X 18 -Y 480 -W 110 -H 34 -Primary $false
    $taskDisable = New-StyledButton -Text "Disable Selected" -X 138 -Y 480 -W 155 -H 34 -Primary $true
    $taskRestore = New-StyledButton -Text "Enable Selected" -X 303 -Y 480 -W 150 -H 34 -Primary $false
    $taskPage.Controls.Add($taskRefresh)
    $taskPage.Controls.Add($taskDisable)
    $taskPage.Controls.Add($taskRestore)

    $script:TaskData = @()

    $loadTasks = {
        $taskList.Items.Clear()
        $script:TaskData = @(Get-WinDebloaterScheduledTasks)

        foreach ($task in $script:TaskData) {
            $row = New-Object System.Windows.Forms.ListViewItem($task.TaskName)
            [void]$row.SubItems.Add($task.TaskPath)
            [void]$row.SubItems.Add($task.State)
            [void]$row.SubItems.Add($task.Recommendation)
            [void]$row.SubItems.Add($task.Risk)
            $row.Tag = $task
            [void]$taskList.Items.Add($row)
        }
    }

    $taskRefresh.Add_Click($loadTasks)

    $taskDisable.Add_Click({
        if ($taskList.SelectedItems.Count -eq 0) {
            return
        }

        $task = $taskList.SelectedItems[0].Tag
        Disable-WinDebloaterScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Risk $task.Risk
        & $loadTasks
    })

    $taskRestore.Add_Click({
        if ($taskList.SelectedItems.Count -eq 0) {
            return
        }

        $task = $taskList.SelectedItems[0].Tag
        Restore-WinDebloaterScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath
        & $loadTasks
    })

    & $loadTasks

    # ------------------------------------------------------------------------
    # Cleanup / Visuals
    # ------------------------------------------------------------------------

    $cleanupPage = New-Object System.Windows.Forms.TabPage
    $cleanupPage.Text = "Cleanup & Performance"
    $cleanupPage.BackColor = $Theme.Background
    $tabs.TabPages.Add($cleanupPage)

    $cleanupTitle = New-Object System.Windows.Forms.Label
    $cleanupTitle.Text = "Safe Performance Actions"
    $cleanupTitle.Location = New-Object System.Drawing.Point(22,22)
    $cleanupTitle.AutoSize = $true
    $cleanupTitle.Font = New-Object System.Drawing.Font($FontFamily,13,[System.Drawing.FontStyle]::Bold)
    $cleanupTitle.ForeColor = $Theme.TextPrimary
    $cleanupPage.Controls.Add($cleanupTitle)

    $cleanupDescription = New-Object System.Windows.Forms.Label
    $cleanupDescription.Text = "These actions are designed for older PCs while avoiding aggressive service removal."
    $cleanupDescription.Location = New-Object System.Drawing.Point(22,52)
    $cleanupDescription.AutoSize = $true
    $cleanupDescription.ForeColor = $Theme.TextMuted
    $cleanupPage.Controls.Add($cleanupDescription)

    $tempButton = New-StyledButton -Text "Clean Temporary Files" -X 22 -Y 100 -W 220 -H 42 -Primary $true
    $lowEndButton = New-StyledButton -Text "Apply Low-End Profile" -X 262 -Y 100 -W 220 -H 42 -Primary $false
    $visualButton = New-StyledButton -Text "Optimize Visual Effects" -X 502 -Y 100 -W 220 -H 42 -Primary $false
    $summaryButton = New-StyledButton -Text "System Summary" -X 742 -Y 100 -W 180 -H 42 -Primary $false

    $cleanupPage.Controls.Add($tempButton)
    $cleanupPage.Controls.Add($lowEndButton)
    $cleanupPage.Controls.Add($visualButton)
    $cleanupPage.Controls.Add($summaryButton)

    $tempButton.Add_Click({
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Clean temporary files and recycle-bin contents where possible?",
            "Confirm Cleanup",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            Clear-WinDebloaterTempFiles
        }
    })

    $lowEndButton.Add_Click({
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Apply the safe low-end optimization profile?`n`nAnimations and fades will be reduced while transparency remains enabled.",
            "Low-End Optimization",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            Set-WinDebloaterLowEndOptimization
        }
    })

    $visualButton.Add_Click({
        Set-WinDebloaterVisualPerformance -DisableAnimations $true -DisableFades $true -KeepTransparency $true
    })

    $summaryButton.Add_Click({
        $summary = Get-WinDebloaterSystemSummary

        [System.Windows.Forms.MessageBox]::Show(
            "Computer: $($summary.ComputerName)`nWindows: $($summary.Windows)`nVersion: $($summary.Version)`nBuild: $($summary.Build)`nCPU: $($summary.CPU)`nRAM: $($summary.RAMGB) GB",
            "System Summary",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    })

    $f.ShowDialog() | Out-Null
    $f.Dispose()
}

# ============================================================================ 
#  CUSTOM WINDOWS ISO BUILDER WINDOW
# ============================================================================

function Show-CustomWindowsIsoBuilder {

    $f = New-ProfessionalForm -Title "Win-Debloater — Custom Windows ISO Builder" -Width 1180 -Height 780
    New-ProfessionalHeader -TargetForm $f -Title "Custom Windows ISO Builder" -Subtitle "Create a user-configured Windows 10 / 11 installation image"

    $workflow = New-Object System.Windows.Forms.Label
    $workflow.Text = "1 Select Image   →   2 Configure   →   3 Debloat   →   4 Optimize   →   5 Applications   →   6 Post Setup   →   7 Build ISO"
    $workflow.Location = New-Object System.Drawing.Point(22,88)
    $workflow.AutoSize = $true
    $workflow.Font = New-Object System.Drawing.Font($FontFamily,9,[System.Drawing.FontStyle]::Bold)
    $workflow.ForeColor = $Theme.Accent
    $f.Controls.Add($workflow)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Location = New-Object System.Drawing.Point(18,120)
    $tabs.Size = New-Object System.Drawing.Size(1140,560)
    $f.Controls.Add($tabs)

    # ------------------------------------------------------------------------
    # Select Windows Image
    # ------------------------------------------------------------------------

    $imagePage = New-Object System.Windows.Forms.TabPage
    $imagePage.Text = "Select Windows Image"
    $imagePage.BackColor = $Theme.Background
    $tabs.TabPages.Add($imagePage)

    $imageInfo = New-Object System.Windows.Forms.Label
    $imageInfo.Text = "Select a Windows 10 or Windows 11 ISO. The original ISO is never modified."
    $imageInfo.Location = New-Object System.Drawing.Point(22,22)
    $imageInfo.AutoSize = $true
    $imageInfo.ForeColor = $Theme.TextMuted
    $imagePage.Controls.Add($imageInfo)

    $imagePath = New-Object System.Windows.Forms.TextBox
    $imagePath.Location = New-Object System.Drawing.Point(22,58)
    $imagePath.Size = New-Object System.Drawing.Size(820,30)
    $imagePath.BackColor = $Theme.PanelAlt
    $imagePath.ForeColor = $Theme.TextPrimary
    $imagePage.Controls.Add($imagePath)

    $browseIso = New-StyledButton -Text "Browse ISO" -X 855 -Y 55 -W 130 -H 35 -Primary $true
    $imagePage.Controls.Add($browseIso)

    $imageList = New-ProfessionalListView -X 22 -Y 110 -W 1060 -H 350
    [void]$imageList.Columns.Add("Index",80)
    [void]$imageList.Columns.Add("Edition",350)
    [void]$imageList.Columns.Add("Description",470)
    [void]$imageList.Columns.Add("Size",100)
    $imagePage.Controls.Add($imageList)

    $browseIso.Add_Click({
        $selected = Select-WinDebloaterIsoSource

        if ($selected) {
            $imagePath.Text = $selected
            $imageList.Items.Clear()

            $images = @(Get-WinDebloaterIsoImages -ImagePath $selected)

            foreach ($img in $images) {
                $row = New-Object System.Windows.Forms.ListViewItem([string]$img.Index)
                [void]$row.SubItems.Add($img.Name)
                [void]$row.SubItems.Add($img.Description)
                [void]$row.SubItems.Add("$($img.SizeGB) GB")
                $row.Tag = $img
                [void]$imageList.Items.Add($row)
            }
        }
    })

    # ------------------------------------------------------------------------
    # Configure
    # ------------------------------------------------------------------------

    $configurePage = New-Object System.Windows.Forms.TabPage
    $configurePage.Text = "Configure"
    $configurePage.BackColor = $Theme.Background
    $tabs.TabPages.Add($configurePage)

    $editionLabel = New-Object System.Windows.Forms.Label
    $editionLabel.Text = "Selected edition:"
    $editionLabel.Location = New-Object System.Drawing.Point(22,25)
    $editionLabel.AutoSize = $true
    $editionLabel.ForeColor = $Theme.TextPrimary
    $configurePage.Controls.Add($editionLabel)

    $editionBox = New-Object System.Windows.Forms.TextBox
    $editionBox.Location = New-Object System.Drawing.Point(160,21)
    $editionBox.Size = New-Object System.Drawing.Size(500,28)
    $editionBox.ReadOnly = $true
    $editionBox.BackColor = $Theme.PanelAlt
    $editionBox.ForeColor = $Theme.TextPrimary
    $configurePage.Controls.Add($editionBox)

    $archLabel = New-Object System.Windows.Forms.Label
    $archLabel.Text = "Architecture:"
    $archLabel.Location = New-Object System.Drawing.Point(22,75)
    $archLabel.AutoSize = $true
    $configurePage.Controls.Add($archLabel)

    $archBox = New-Object System.Windows.Forms.ComboBox
    $archBox.Location = New-Object System.Drawing.Point(160,71)
    $archBox.Size = New-Object System.Drawing.Size(220,28)
    $archBox.DropDownStyle = "DropDownList"
    [void]$archBox.Items.Add("x64")
    [void]$archBox.Items.Add("x86")
    [void]$archBox.Items.Add("ARM64")
    $archBox.SelectedIndex = 0
    $configurePage.Controls.Add($archBox)

    $profileLabel = New-Object System.Windows.Forms.Label
    $profileLabel.Text = "Optimization profile:"
    $profileLabel.Location = New-Object System.Drawing.Point(22,125)
    $profileLabel.AutoSize = $true
    $configurePage.Controls.Add($profileLabel)

    $profileBox = New-Object System.Windows.Forms.ComboBox
    $profileBox.Location = New-Object System.Drawing.Point(160,121)
    $profileBox.Size = New-Object System.Drawing.Size(300,28)
    $profileBox.DropDownStyle = "DropDownList"
    [void]$profileBox.Items.Add("Balanced")
    [void]$profileBox.Items.Add("Low-End Safe")
    [void]$profileBox.Items.Add("Advanced")
    $profileBox.SelectedIndex = 0
    $configurePage.Controls.Add($profileBox)

    $safeLabel = New-Object System.Windows.Forms.Label
    $safeLabel.Text = "Recommended / Safe`n`n• Optional app removal`n• Safe privacy tweaks`n• Temporary-file cleanup`n• Visual-effect optimization`n• User-selected configuration"
    $safeLabel.Location = New-Object System.Drawing.Point(22,190)
    $safeLabel.Size = New-Object System.Drawing.Size(420,180)
    $safeLabel.ForeColor = $Theme.Success
    $configurePage.Controls.Add($safeLabel)

    $advancedLabel = New-Object System.Windows.Forms.Label
    $advancedLabel.Text = "Advanced / Potentially Risky`n`n• Windows component removal`n• Unfamiliar services`n• Aggressive system modifications`n• Removing dependencies"
    $advancedLabel.Location = New-Object System.Drawing.Point(480,190)
    $advancedLabel.Size = New-Object System.Drawing.Size(420,180)
    $advancedLabel.ForeColor = $Theme.Warning
    $configurePage.Controls.Add($advancedLabel)

    # ------------------------------------------------------------------------
    # Debloat
    # ------------------------------------------------------------------------

    $debloatPage = New-Object System.Windows.Forms.TabPage
    $debloatPage.Text = "Debloat"
    $debloatPage.BackColor = $Theme.Background
    $tabs.TabPages.Add($debloatPage)

    $debloatInfo = New-Object System.Windows.Forms.Label
    $debloatInfo.Text = "Select individual applications. Nothing is removed unless selected."
    $debloatInfo.Location = New-Object System.Drawing.Point(22,22)
    $debloatInfo.AutoSize = $true
    $debloatInfo.ForeColor = $Theme.TextMuted
    $debloatPage.Controls.Add($debloatInfo)

    $debloatList = New-Object System.Windows.Forms.CheckedListBox
    $debloatList.Location = New-Object System.Drawing.Point(22,60)
    $debloatList.Size = New-Object System.Drawing.Size(1050,390)
    $debloatList.BackColor = $Theme.PanelAlt
    $debloatList.ForeColor = $Theme.TextPrimary
    $debloatList.CheckOnClick = $true
    $debloatList.Font = New-Object System.Drawing.Font($FontFamily,9.5)
    $debloatPage.Controls.Add($debloatList)

    foreach ($app in $script:IsoSafeApps) {
        [void]$debloatList.Items.Add($app,$false)
    }

    $selectAllIsoApps = New-StyledButton -Text "Select All" -X 22 -Y 470 -W 120 -H 35 -Primary $false
    $selectNoneIsoApps = New-StyledButton -Text "Select None" -X 152 -Y 470 -W 120 -H 35 -Primary $false
    $debloatPage.Controls.Add($selectAllIsoApps)
    $debloatPage.Controls.Add($selectNoneIsoApps)

    $selectAllIsoApps.Add_Click({
        for ($i=0;$i -lt $debloatList.Items.Count;$i++) {
            $debloatList.SetItemChecked($i,$true)
        }
    })

    $selectNoneIsoApps.Add_Click({
        for ($i=0;$i -lt $debloatList.Items.Count;$i++) {
            $debloatList.SetItemChecked($i,$false)
        }
    })

    # ------------------------------------------------------------------------
    # Components
    # ------------------------------------------------------------------------

    $componentsPage = New-Object System.Windows.Forms.TabPage
    $componentsPage.Text = "Components"
    $componentsPage.BackColor = $Theme.Background
    $tabs.TabPages.Add($componentsPage)

    $componentWarning = New-Object System.Windows.Forms.Label
    $componentWarning.Text = "Advanced component removal can affect Windows functionality. Review every item carefully."
    $componentWarning.Location = New-Object System.Drawing.Point(22,22)
    $componentWarning.AutoSize = $true
    $componentWarning.ForeColor = $Theme.Warning
    $componentsPage.Controls.Add($componentWarning)

    $componentList = New-Object System.Windows.Forms.CheckedListBox
    $componentList.Location = New-Object System.Drawing.Point(22,60)
    $componentList.Size = New-Object System.Drawing.Size(1050,390)
    $componentList.BackColor = $Theme.PanelAlt
    $componentList.ForeColor = $Theme.TextPrimary
    $componentList.CheckOnClick = $true
    $componentsPage.Controls.Add($componentList)

    foreach ($component in $script:IsoAdvancedComponents) {
        [void]$componentList.Items.Add($component,$false)
    }

    # ------------------------------------------------------------------------
    # Applications
    # ------------------------------------------------------------------------

    $applicationsPage = New-Object System.Windows.Forms.TabPage
    $applicationsPage.Text = "Applications"
    $applicationsPage.BackColor = $Theme.Background
    $tabs.TabPages.Add($applicationsPage)

    $applicationInfo = New-Object System.Windows.Forms.Label
    $applicationInfo.Text = "Add EXE/MSI installers to the ISO workflow. Applications are not automatically executed unless configured in Post Setup."
    $applicationInfo.Location = New-Object System.Drawing.Point(22,22)
    $applicationInfo.AutoSize = $true
    $applicationInfo.ForeColor = $Theme.TextMuted
    $applicationsPage.Controls.Add($applicationInfo)

    $applicationList = New-ProfessionalListView -X 22 -Y 60 -W 1050 -H 350
    [void]$applicationList.Columns.Add("Application",300)
    [void]$applicationList.Columns.Add("Path",550)
    [void]$applicationList.Columns.Add("Type",100)
    $applicationsPage.Controls.Add($applicationList)

    $addApplication = New-StyledButton -Text "Add Application" -X 22 -Y 430 -W 150 -H 35 -Primary $true
    $removeApplication = New-StyledButton -Text "Remove Selected" -X 182 -Y 430 -W 150 -H 35 -Primary $false
    $applicationsPage.Controls.Add($addApplication)
    $applicationsPage.Controls.Add($removeApplication)

    $addApplication.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = "Installers (*.exe;*.msi)|*.exe;*.msi|All files (*.*)|*.*"
        $dialog.Multiselect = $true

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            foreach ($path in $dialog.FileNames) {
                $type = [System.IO.Path]::GetExtension($path).TrimStart(".").ToUpper()

                $entry = [PSCustomObject]@{
                    Name = [System.IO.Path]::GetFileName($path)
                    Path = $path
                    Type = $type
                }

                $script:IsoConfig.AddedApplications += $entry

                $row = New-Object System.Windows.Forms.ListViewItem($entry.Name)
                [void]$row.SubItems.Add($entry.Path)
                [void]$row.SubItems.Add($entry.Type)
                $row.Tag = $entry
                [void]$applicationList.Items.Add($row)
            }
        }
    })

    $removeApplication.Add_Click({
        if ($applicationList.SelectedItems.Count -eq 0) {
            return
        }

        $entry = $applicationList.SelectedItems[0].Tag
        $script:IsoConfig.AddedApplications = @(
            $script:IsoConfig.AddedApplications |
                Where-Object { $_.Path -ne $entry.Path }
        )

        $applicationList.Items.Remove($applicationList.SelectedItems[0])
    })

    # ------------------------------------------------------------------------
    # Post Setup
    # ------------------------------------------------------------------------

    $postPage = New-Object System.Windows.Forms.TabPage
    $postPage.Text = "Post Setup"
    $postPage.BackColor = $Theme.Background
    $tabs.TabPages.Add($postPage)

    $postInfo = New-Object System.Windows.Forms.Label
    $postInfo.Text = "After Login actions execute after the user logs into the customized Windows installation."
    $postInfo.Location = New-Object System.Drawing.Point(22,22)
    $postInfo.AutoSize = $true
    $postInfo.ForeColor = $Theme.TextMuted
    $postPage.Controls.Add($postInfo)

    $postList = New-ProfessionalListView -X 22 -Y 60 -W 1050 -H 330
    [void]$postList.Columns.Add("Type",100)
    [void]$postList.Columns.Add("Action",350)
    [void]$postList.Columns.Add("Stage",130)
    [void]$postList.Columns.Add("Silent",80)
    [void]$postList.Columns.Add("Run Once",100)
    [void]$postList.Columns.Add("Order",70)
    $postPage.Controls.Add($postList)

    $addPost = New-StyledButton -Text "Add Action" -X 22 -Y 410 -W 130 -H 35 -Primary $true
    $removePost = New-StyledButton -Text "Remove Selected" -X 162 -Y 410 -W 150 -H 35 -Primary $false
    $postPage.Controls.Add($addPost)
    $postPage.Controls.Add($removePost)

    $postType = New-Object System.Windows.Forms.ComboBox
    $postType.Location = New-Object System.Drawing.Point(330,413)
    $postType.Size = New-Object System.Drawing.Size(120,25)
    $postType.DropDownStyle = "DropDownList"
    foreach ($type in @("EXE","MSI","BAT","CMD","PowerShell")) {
        [void]$postType.Items.Add($type)
    }
    $postType.SelectedIndex = 0
    $postPage.Controls.Add($postType)

    $silentCheck = New-Object System.Windows.Forms.CheckBox
    $silentCheck.Text = "Silent / Passive"
    $silentCheck.Location = New-Object System.Drawing.Point(470,413)
    $silentCheck.AutoSize = $true
    $silentCheck.ForeColor = $Theme.TextPrimary
    $postPage.Controls.Add($silentCheck)

    $runOnceCheck = New-Object System.Windows.Forms.CheckBox
    $runOnceCheck.Text = "Run Once"
    $runOnceCheck.Location = New-Object System.Drawing.Point(610,413)
    $runOnceCheck.AutoSize = $true
    $runOnceCheck.Checked = $true
    $runOnceCheck.ForeColor = $Theme.TextPrimary
    $postPage.Controls.Add($runOnceCheck)

    $postOrder = New-Object System.Windows.Forms.NumericUpDown
    $postOrder.Location = New-Object System.Drawing.Point(720,410)
    $postOrder.Size = New-Object System.Drawing.Size(80,25)
    $postOrder.Minimum = 0
    $postOrder.Maximum = 999
    $postPage.Controls.Add($postOrder)

    $postPath = New-Object System.Windows.Forms.TextBox
    $postPath.Location = New-Object System.Drawing.Point(22,455)
    $postPath.Size = New-Object System.Drawing.Size(780,28)
    $postPath.BackColor = $Theme.PanelAlt
    $postPath.ForeColor = $Theme.TextPrimary
    $postPage.Controls.Add($postPath)

    $browsePost = New-StyledButton -Text "Browse" -X 815 -Y 452 -W 110 -H 34 -Primary $false
    $postPage.Controls.Add($browsePost)

    $refreshPost = New-StyledButton -Text "Refresh" -X 935 -Y 452 -W 110 -H 34 -Primary $false
    $postPage.Controls.Add($refreshPost)

    $refreshPost.Add_Click({
        $postList.Items.Clear()

        foreach ($action in @($script:IsoConfig.PostSetupActions | Sort-Object Order)) {
            $row = New-Object System.Windows.Forms.ListViewItem($action.Type)
            [void]$row.SubItems.Add($action.Path)
            [void]$row.SubItems.Add($action.Stage)
            [void]$row.SubItems.Add([string]$action.Silent)
            [void]$row.SubItems.Add([string]$action.RunOnce)
            [void]$row.SubItems.Add([string]$action.Order)
            $row.Tag = $action
            [void]$postList.Items.Add($row)
        }
    })

    $browsePost.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Filter = "All supported files (*.exe;*.msi;*.bat;*.cmd;*.ps1)|*.exe;*.msi;*.bat;*.cmd;*.ps1|All files (*.*)|*.*"

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $postPath.Text = $dialog.FileName
        }
    })

    $addPost.Add_Click({
        if (-not $postPath.Text) {
            [System.Windows.Forms.MessageBox]::Show(
                "Select an application, script, or command file first.",
                "Post Setup",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            return
        }

        Add-WinDebloaterPostSetupAction `
            -Type $postType.Text `
            -Path $postPath.Text `
            -Arguments "" `
            -Stage "After Login" `
            -Silent $silentCheck.Checked `
            -RunOnce $runOnceCheck.Checked `
            -Order ([int]$postOrder.Value)

        & $refreshPost
    })

    $removePost.Add_Click({
        if ($postList.SelectedItems.Count -eq 0) {
            return
        }

        Remove-WinDebloaterPostSetupAction -Id $postList.SelectedItems[0].Tag.Id
        & $refreshPost
    })

    # ------------------------------------------------------------------------
    # Build
    # ------------------------------------------------------------------------

    $buildPage = New-Object System.Windows.Forms.TabPage
    $buildPage.Text = "Build ISO"
    $buildPage.BackColor = $Theme.Background
    $tabs.TabPages.Add($buildPage)

    $buildTitle = New-Object System.Windows.Forms.Label
    $buildTitle.Text = "Review & Build"
    $buildTitle.Location = New-Object System.Drawing.Point(22,22)
    $buildTitle.AutoSize = $true
    $buildTitle.Font = New-Object System.Drawing.Font($FontFamily,14,[System.Drawing.FontStyle]::Bold)
    $buildTitle.ForeColor = $Theme.TextPrimary
    $buildPage.Controls.Add($buildTitle)

    $buildSummary = New-Object System.Windows.Forms.Label
    $buildSummary.Location = New-Object System.Drawing.Point(22,62)
    $buildSummary.Size = New-Object System.Drawing.Size(1000,220)
    $buildSummary.ForeColor = $Theme.TextMuted
    $buildPage.Controls.Add($buildSummary)

    $outputPath = New-Object System.Windows.Forms.TextBox
    $outputPath.Location = New-Object System.Drawing.Point(22,310)
    $outputPath.Size = New-Object System.Drawing.Size(780,30)
    $outputPath.BackColor = $Theme.PanelAlt
    $outputPath.ForeColor = $Theme.TextPrimary
    $buildPage.Controls.Add($outputPath)

    $browseOutput = New-StyledButton -Text "Output ISO" -X 815 -Y 307 -W 130 -H 35 -Primary $false
    $buildPage.Controls.Add($browseOutput)

    $buildProgress = New-Object System.Windows.Forms.ProgressBar
    $buildProgress.Location = New-Object System.Drawing.Point(22,370)
    $buildProgress.Size = New-Object System.Drawing.Size(1020,25)
    $buildPage.Controls.Add($buildProgress)

    $buildButton = New-StyledButton -Text "Build Customized ISO" -X 22 -Y 420 -W 220 -H 45 -Primary $true
    $buildPage.Controls.Add($buildButton)

    $browseOutput.Add_Click({
        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Filter = "ISO image (*.iso)|*.iso"
        $dialog.FileName = "Win-Debloater-Custom.iso"

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $outputPath.Text = $dialog.FileName
        }
    })

    $tabs.Add_Selected({
        if ($tabs.SelectedTab -eq $buildPage) {

            $appsSelected = 0
            for ($i=0;$i -lt $debloatList.Items.Count;$i++) {
                if ($debloatList.GetItemChecked($i)) {
                    $appsSelected++
                }
            }

            $componentsSelected = 0
            for ($i=0;$i -lt $componentList.Items.Count;$i++) {
                if ($componentList.GetItemChecked($i)) {
                    $componentsSelected++
                }
            }

            $editionText = ""
            $indexText = ""

            if ($imageList.SelectedItems.Count -gt 0) {
                $selectedImage = $imageList.SelectedItems[0].Tag
                $editionText = $selectedImage.Name
                $indexText = [string]$selectedImage.Index
            }

            $buildSummary.Text =
                "Source ISO: $($imagePath.Text)`r`n" +
                "Edition: $editionText`r`n" +
                "Image Index: $indexText`r`n" +
                "Architecture: $($archBox.Text)`r`n" +
                "Optimization Profile: $($profileBox.Text)`r`n`r`n" +
                "Applications selected for removal: $appsSelected`r`n" +
                "Advanced components selected: $componentsSelected`r`n" +
                "Additional applications: $($script:IsoConfig.AddedApplications.Count)`r`n" +
                "Post Setup actions: $($script:IsoConfig.PostSetupActions.Count)"
        }
    })

    $buildButton.Add_Click({

        if (-not $imagePath.Text -or -not (Test-Path $imagePath.Text)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Select a valid Windows ISO first.",
                "ISO Builder",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        if (-not $outputPath.Text) {
            [System.Windows.Forms.MessageBox]::Show(
                "Select an output ISO path first.",
                "ISO Builder",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        if ($imageList.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Select a Windows image/edition first.",
                "ISO Builder",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        $script:IsoConfig.SourceImage = $imagePath.Text
        $script:IsoConfig.OutputISO = $outputPath.Text
        $script:IsoConfig.Architecture = $archBox.Text
        $script:IsoConfig.OptimizationProfile = $profileBox.Text

        $script:IsoConfig.RemoveApps = @()

        for ($i=0;$i -lt $debloatList.Items.Count;$i++) {
            if ($debloatList.GetItemChecked($i)) {
                $script:IsoConfig.RemoveApps += $debloatList.Items[$i].ToString()
            }
        }

        $script:IsoConfig.RemoveComponents = @()

        for ($i=0;$i -lt $componentList.Items.Count;$i++) {
            if ($componentList.GetItemChecked($i)) {
                $script:IsoConfig.RemoveComponents += $componentList.Items[$i].ToString()
            }
        }

        $selectedImage = $imageList.SelectedItems[0].Tag

        $buildButton.Enabled = $false
        $buildProgress.Style = "Marquee"

        try {
            Export-WinDebloaterPostSetupFiles -DestinationRoot (Split-Path $outputPath.Text -Parent)

            $success = Invoke-WinDebloaterIsoBuild `
                -SourceISO $script:IsoConfig.SourceImage `
                -OutputISO $script:IsoConfig.OutputISO `
                -ImageIndex ([int]$selectedImage.Index) `
                -Profile $script:IsoConfig.OptimizationProfile

            if ($success) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Customized ISO creation completed successfully.",
                    "ISO Builder",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }
        } finally {
            $buildProgress.Style = "Continuous"
            $buildProgress.Value = 0
            $buildButton.Enabled = $true
        }
    })

    $f.ShowDialog() | Out-Null
    $f.Dispose()
}

# ============================================================================ 
#  MAIN APPLICATION NAVIGATION
#  Existing Win-Debloater controls remain available.
# ============================================================================

$navigationPanel = New-Object System.Windows.Forms.Panel
$navigationPanel.Location = New-Object System.Drawing.Point(20,68)
$navigationPanel.Size = New-Object System.Drawing.Size(940,48)
$navigationPanel.BackColor = $Theme.Background
$form.Controls.Add($navigationPanel)

$optimizationButton = New-StyledButton `
    -Text "⚙ Windows Optimization" `
    -X 0 -Y 5 -W 205 -H 36 -Primary $false

$isoBuilderButton = New-StyledButton `
    -Text "▣ Custom ISO Builder" `
    -X 215 -Y 5 -W 190 -H 36 -Primary $false

$systemSummaryButton = New-StyledButton `
    -Text "System Info" `
    -X 415 -Y 5 -W 125 -H 36 -Primary $false

$navigationPanel.Controls.Add($optimizationButton)
$navigationPanel.Controls.Add($isoBuilderButton)
$navigationPanel.Controls.Add($systemSummaryButton)

$optimizationButton.Add_Click({
    Show-WindowsOptimizationWindow
})

$isoBuilderButton.Add_Click({
    Show-CustomWindowsIsoBuilder
})

$systemSummaryButton.Add_Click({
    $summary = Get-WinDebloaterSystemSummary
    $disks = @(Get-WinDebloaterDiskInfo)

    $diskText = ""

    foreach ($disk in $disks) {
        $diskText += "`n$($disk.DeviceID)  Free: $($disk.FreeGB) GB / $($disk.SizeGB) GB"
    }

    [System.Windows.Forms.MessageBox]::Show(
        "Computer: $($summary.ComputerName)`n`nWindows: $($summary.Windows)`nVersion: $($summary.Version)`nBuild: $($summary.Build)`n`nCPU: $($summary.CPU)`nRAM: $($summary.RAMGB) GB`n`nDisk:$diskText",
        "Win-Debloater — System Information",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
})

# ============================================================================ 
#  PROFESSIONAL MAIN FORM TOOLTIP
# ============================================================================

$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 8000
$toolTip.InitialDelay = 300
$toolTip.ReshowDelay = 200

$toolTip.SetToolTip(
    $optimizationButton,
    "Manage startup applications, services, scheduled tasks, temporary files and visual performance settings."
)

$toolTip.SetToolTip(
    $isoBuilderButton,
    "Create a customized Windows 10/11 ISO with selectable debloating, optimization and Post Setup configuration."
)

$toolTip.SetToolTip(
    $systemSummaryButton,
    "View Windows, CPU, RAM and disk information."
)

# ============================================================================ 
#  SHOW FORM 
# ============================================================================ 
[void]$form.ShowDialog()
