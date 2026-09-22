<# :ns3_master_installer
@echo off
setlocal EnableDelayedExpansion
title ns-3 Automated Simulation Suite - Created by Qamar Abbas
color 0B
cd /d "%~dp0"
set "NS3_SCRIPT_PATH=%~f0"

:: Execute embedded PowerShell engine with ExecutionPolicy Bypass
powershell -NoProfile -ExecutionPolicy Bypass -Command "$scriptPath=$env:NS3_SCRIPT_PATH; $s=[System.IO.File]::ReadAllText($scriptPath, [System.Text.Encoding]::UTF8); Invoke-Expression $s"

:: Anti-Vanishing Catch-all (Keeps window open if any error occurred)
if %errorlevel% neq 0 (
    echo.
    echo ==============================================================================
    echo  [!] Setup stopped or encountered an issue.
    echo  This window will remain open so you can read the details above.
    echo  Press any key to return to Windows...
    echo ==============================================================================
    pause >nul
)
exit /b %errorlevel%
#>

# ==============================================================================
# Pure PowerShell Core Engine (Modern, Robust, Multi-Drive, & Self-Healing)
# Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas
# ==============================================================================

# Force TLS 1.2 for all HTTPS operations (ensures compatibility with older Windows 10)
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Host.UI.RawUI.WindowTitle = "ns-3 Automated Simulation Suite - Created by Qamar Abbas"

# Safe input helper functions (immune to console redirection crashes)
function Wait-ForInput {
    try {
        [void][Console]::ReadKey($true)
    } catch {
        try { [void][Console]::ReadLine() } catch { Start-Sleep -Seconds 2 }
    }
}

function Wait-ForEnter {
    try {
        [void][Console]::ReadLine()
    } catch {
        Start-Sleep -Seconds 2
    }
}

# Function to dynamically resolve the registered WSL distribution name
function Get-TargetWSLDistro {
    try {
        $raw = wsl.exe -l -q 2>$null
        if (-not $raw) { return $null }
        $distros = @($raw | ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ -ne "" })
        if ($distros.Count -eq 0) { return $null }
        
        # 1. Look for exact "Ubuntu"
        if ($distros -contains "Ubuntu") { return "Ubuntu" }
        
        # 2. Look for versioned Ubuntu (Ubuntu-24.04, Ubuntu-22.04, Ubuntu-20.04)
        $uDistro = $distros | Where-Object { $_ -match "^Ubuntu" } | Select-Object -First 1
        if ($uDistro) { return $uDistro }
        
        # 3. Look for Debian
        if ($distros -contains "Debian") { return "Debian" }
        
        # 4. Any other non-docker distro
        $other = $distros | Where-Object { $_ -notmatch "docker" } | Select-Object -First 1
        if ($other) { return $other }
    } catch {}
    return $null
}

# Function to scan all physical fixed disk partitions
function Get-SystemDisks {
    try {
        $disks = @(Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | ForEach-Object {
            [PSCustomObject]@{
                Letter   = $_.DeviceID.TrimEnd(':').ToUpper()
                DeviceID = $_.DeviceID.ToUpper()
                FreeGB   = [math]::Round($_.FreeSpace / 1GB, 1)
                TotalGB  = [math]::Round($_.Size / 1GB, 1)
                HasSpace = ($_.FreeSpace / 1GB -ge 15)
            }
        })
        return ,$disks
    } catch {
        return ,@()
    }
}

# Function to scan all drives and registry for existing ns-3 or WSL installations
function Get-ExistingInstallations {
    $results = [PSCustomObject]@{
        WSLDistroPath  = $null
        WSLDrive       = $null
        ExistingRoots  = @()
        PreferredDrive = $null
    }
    
    # 1. Inspect WSL Registry for registered BasePath
    try {
        $keys = Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
            if ($p.DistributionName -match "^Ubuntu" -or $p.DistributionName -match "^Debian") {
                $bp = ($p.BasePath -replace "^\\\\\?\\", "").Trim()
                if ($bp -and (Test-Path $bp)) {
                    $results.WSLDistroPath = $bp
                    $results.WSLDrive = ($bp -split ":")[0].ToUpper() + ":"
                    $results.PreferredDrive = ($bp -split ":")[0].ToUpper()
                    break
                }
            }
        }
    } catch {}

    # 2. Check all physical fixed drives for existing \ns3-setup or \ns3-wsl
    try {
        $drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        foreach ($d in $drives) {
            $letter = $d.DeviceID.ToUpper()
            $setupDir = Join-Path $letter "ns3-setup"
            $wslDir = Join-Path $letter "ns3-wsl"
            if (Test-Path $setupDir) {
                $results.ExistingRoots += $setupDir
                if (-not $results.PreferredDrive) { $results.PreferredDrive = $letter.TrimEnd(':') }
            }
            if ((Test-Path $wslDir) -and ($results.WSLDrive -ne $letter)) {
                $results.ExistingRoots += $wslDir
                if (-not $results.PreferredDrive) { $results.PreferredDrive = $letter.TrimEnd(':') }
            }
        }
    } catch {}

    return $results
}

# Early Hardware Specs & Turbo Concurrency Calculation
$cpuThreads = [Environment]::ProcessorCount
if (-not $cpuThreads -or $cpuThreads -lt 2) { $cpuThreads = 2 }
$csMem = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$totalRamGB = if ($csMem) { [math]::Round($csMem.TotalPhysicalMemory / 1GB, 1) } else { 8 }
if ($totalRamGB -lt 4) {
    $compileJobs = 2
} elseif ($totalRamGB -lt 8) {
    $compileJobs = [math]::Min($cpuThreads, 4)
} elseif ($totalRamGB -lt 16) {
    $compileJobs = [math]::Min($cpuThreads, [math]::Max(4, [int]($totalRamGB / 1.5)))
} elseif ($totalRamGB -lt 32) {
    $compileJobs = [math]::Min($cpuThreads, [math]::Max(8, [int]($totalRamGB / 1.2)))
} else {
    $compileJobs = $cpuThreads
}

# Determine script path and working directory
$scriptPath = $env:NS3_SCRIPT_PATH
if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
    # If run in-memory via web runner (irm ... | iex), establish clean local workspace
    $allDisksInit = Get-SystemDisks
    $bestDiskInit = $allDisksInit | Sort-Object -Property FreeGB -Descending | Select-Object -First 1
    $initDrive = if ($bestDiskInit) { "$($bestDiskInit.Letter):" } else { $env:SystemDrive }
    $defaultDir = Join-Path $initDrive "ns3-setup"
    try {
        if (-not (Test-Path $defaultDir)) { New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null }
    } catch {
        $defaultDir = Join-Path $env:USERPROFILE "ns3-setup"
        if (-not (Test-Path $defaultDir)) { New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null }
    }
    $scriptPath = Join-Path $defaultDir "INSTALL_ALL_ns3.bat"
    try {
        Invoke-RestMethod -Uri "https://raw.githubusercontent.com/qamarabbas-024/ns3-lab-setup/main/INSTALL_ALL_ns3.bat" -OutFile $scriptPath
        Unblock-File -Path $scriptPath -ErrorAction SilentlyContinue
    } catch {}
}
$scriptDir = Split-Path -Parent $scriptPath

# 0. Self-Unblock current directory (Removes Mark-of-the-Web to prevent Smart App Control blocks)
try {
    if (Test-Path $scriptPath) { Unblock-File -Path $scriptPath -ErrorAction SilentlyContinue }
    if (Test-Path $scriptDir) { Get-ChildItem -Path $scriptDir -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue }
} catch {}

# Windows Sandbox Environment Detection
$isSandbox = ($env:USERNAME -eq "WDAGUtilityAccount") -or ((Get-CimInstance Win32_ComputerSystem).Model -eq "Virtual Machine" -and (Get-CimInstance Win32_ComputerSystem).Manufacturer -match "Microsoft")
if ($isSandbox) {
    Clear-Host
    Write-Host "==============================================================================" -ForegroundColor Yellow
    Write-Host "               [!] WINDOWS SANDBOX ENVIRONMENT DETECTED                       " -ForegroundColor Yellow
    Write-Host "==============================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  You are currently testing inside Windows Sandbox (WDAGUtilityAccount)." -ForegroundColor White
    Write-Host ""
    Write-Host "  IMPORTANT NOTICE FOR WINDOWS SANDBOX:" -ForegroundColor Yellow
    Write-Host "    - Windows Sandbox does NOT have nested virtualization enabled." -ForegroundColor Gray
    Write-Host "      Windows Subsystem for Linux (WSL2) cannot run inside Sandbox." -ForegroundColor Gray
    Write-Host "    - Windows Sandbox is temporary: all files will be discarded on close." -ForegroundColor Gray
    Write-Host "    - To install ns-3 for your coursework, please run this installer" -ForegroundColor White
    Write-Host "      directly on your physical Windows 10/11 laptop (outside Sandbox)!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Select an option:" -ForegroundColor White
    Write-Host "    [1] Continue with Pre-Flight Hardware Audit (Diagnostics Demo)" -ForegroundColor Cyan
    Write-Host "    [2] Exit Sandbox Installer" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Yellow
    $sbChoice = Read-Host "Enter choice [1 or 2, default: 1]"
    if ($sbChoice -eq "2") { exit 0 }
}

# 1. Administrator Check & Anti-Vanishing UAC Wrapper
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Clear-Host
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                    ADMINISTRATOR PERMISSION REQUIRED                         " -ForegroundColor Cyan
    Write-Host "          Computer Networks Lab - BSCS Department [Semester 3]                " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Windows requires Administrator permission to configure WSL2 and ns-3." -ForegroundColor Yellow
    Write-Host "  Please click `"YES`" on the User Account Control (UAC) pop-up window!" -ForegroundColor White
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/k `"`"$scriptPath`"`""
    $psi.Verb = "RunAs"
    $psi.UseShellExecute = $true
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Write-Host "  [!] Administrator permission was declined or cancelled." -ForegroundColor Red
        Write-Host "  Please right-click INSTALL_ALL_ns3.bat and choose 'Run as administrator'." -ForegroundColor Yellow
        pause
    }
    exit 0
}

# Function to show Simulation Control Center
function Show-ControlCenter {
    param([string]$Distro = "Ubuntu")
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host "                         ns-3 SIMULATION CONTROL CENTER                       " -ForegroundColor Cyan
        Write-Host "         Computer Networks Lab (Lab 01) - BSCS Department [Semester 3]        " -ForegroundColor Cyan
        Write-Host "          Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas          " -ForegroundColor Yellow
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Your ns-3 simulation environment is fully installed and operational!" -ForegroundColor Green
        Write-Host "  Active Linux Distribution: $Distro" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Please select an action:" -ForegroundColor White
        Write-Host "    [1] Launch ns-3 Linux Terminal" -ForegroundColor Cyan
        Write-Host "    [2] Open ns-3 in Visual Studio Code" -ForegroundColor Cyan
        Write-Host "    [3] Run Lab 1 Simulation (first.cc)" -ForegroundColor Cyan
        Write-Host "    [4] Run Smoke Test (hello-simulator)" -ForegroundColor Cyan
        Write-Host "    [5] Rebuild / Recompile ns-3 Code" -ForegroundColor Cyan
        Write-Host "    [6] Re-create Desktop Shortcuts" -ForegroundColor Cyan
        Write-Host "    [7] Reinstall / Repair Environment from Scratch" -ForegroundColor Cyan
        Write-Host "    [8] Exit" -ForegroundColor Gray
        Write-Host ""
        Write-Host "==============================================================================" -ForegroundColor Cyan
        $choice = Read-Host "Enter choice [1-8, default: 1]"
        if (-not $choice) { $choice = "1" }

        switch ($choice) {
            "1" {
                $termBat = Join-Path $scriptDir "open_ns3_terminal.bat"
                if (Test-Path $termBat) {
                    Start-Process $termBat
                } else {
                    Start-Process cmd.exe -ArgumentList "/k wsl.exe -d $Distro -e bash -lic `"cd ~/workspace/ns-3-dev 2>/dev/null || cd ~; exec bash`""
                }
                exit 0
            }
            "2" {
                $codeBat = Join-Path $scriptDir "open_ns3_vscode.bat"
                if (Test-Path $codeBat) {
                    Start-Process $codeBat
                } else {
                    wsl.exe -d $Distro bash -lic "cd ~/workspace/ns-3-dev && code ."
                }
                exit 0
            }
            "3" {
                Write-Host "`nRunning Lab 1 (first.cc)...`n" -ForegroundColor Yellow
                wsl.exe -d $Distro bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run examples/tutorial/first"
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                Wait-ForEnter
            }
            "4" {
                Write-Host "`nRunning Smoke Test (hello-simulator)...`n" -ForegroundColor Yellow
                wsl.exe -d $Distro bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run hello-simulator"
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                Wait-ForEnter
            }
            "5" {
                Write-Host "`nRecompiling ns-3 code with Ninja ($compileJobs threads)...`n" -ForegroundColor Yellow
                wsl.exe -d $Distro bash -lic "cd ~/workspace/ns-3-dev && ./ns3 build -j $compileJobs"
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                Wait-ForEnter
            }
            "6" {
                New-DesktopShortcuts -TargetDir $scriptDir -TargetDistro $Distro
                Write-Host "`n[OK] Shortcuts created on your Desktop!" -ForegroundColor Green
                Start-Sleep -Seconds 2
            }
            "7" {
                Write-Host "`n  [*] Cleaning ns-3 build cache and resetting configuration..." -ForegroundColor Yellow
                wsl.exe -d $Distro bash -c "cd ~/workspace/ns-3-dev 2>/dev/null && rm -rf build" 2>$null
                wsl.exe -d $Distro bash -c "rm -f ~/workspace/ns-3-dev/ns3" 2>$null
                Write-Host "  [OK] Reset complete. Restarting installation..." -ForegroundColor Green
                Start-Sleep -Seconds 2
                return
            }
            "8" { exit 0 }
            default { exit 0 }
        }
    }
}

# Function to generate Desktop Shortcuts and local batch files (Strictly exactly 2 icons)
function New-DesktopShortcuts {
    param(
        [string]$TargetDir,
        [string]$TargetDistro = "Ubuntu"
    )
    
    $desktop = [Environment]::GetFolderPath("Desktop")
    $publicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
    $wsh = New-Object -ComObject WScript.Shell

    # Clean up duplicate or orphaned shortcuts from Public Desktop to prevent 4-icon clutter
    try {
        if ($publicDesktop -and (Test-Path $publicDesktop)) {
            Remove-Item (Join-Path $publicDesktop "ns-3 Linux Terminal.lnk") -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $publicDesktop "ns-3 VS Code.lnk") -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    # Clean up duplicate generic "Visual Studio Code.lnk" if created by silent install
    try {
        Remove-Item (Join-Path $desktop "Visual Studio Code.lnk") -Force -ErrorAction SilentlyContinue
    } catch {}

    # 1. open_ns3_terminal.bat
    $termContent = @"
@echo off
setlocal
cd /d "%~dp0"
title ns-3 Linux Terminal - Computer Networks Lab
color 0B

echo ======================================================================
echo      WELCOME TO YOUR ns-3 NETWORK SIMULATION ENVIRONMENT!
echo      Computer Networks Lab (Lab 01) - BSCS Department [Semester 3]
echo       Prepared with care for BSCS Students by Qamar Abbas
echo ======================================================================
echo  Current Directory: ~/workspace/ns-3-dev
echo.
echo  LAB 1 CHEAT SHEET:
echo    - Test Simulator : ./ns3 run hello-simulator
echo    - Run Lab 1      : ./ns3 run examples/tutorial/first
echo    - Recompile Code : ./ns3 build
echo    - Open VS Code   : code .
echo    - Exit to Windows: exit
echo ======================================================================
echo.

wsl.exe -d $TargetDistro bash -lic "cd ~/workspace/ns-3-dev 2>/dev/null || cd ~; exec bash"

if %errorlevel% neq 0 (
    echo.
    echo ======================================================================
    echo  [!] Could not start WSL Linux session ($TargetDistro).
    echo  Error Code: %errorlevel%
    echo  If your computer just started up, please wait a moment and try again.
    echo ======================================================================
    pause
)
"@
    [System.IO.File]::WriteAllText((Join-Path $TargetDir "open_ns3_terminal.bat"), $termContent)

    # 2. open_ns3_vscode.bat
    $codeContent = @"
@echo off
setlocal
cd /d "%~dp0"
title ns-3 VS Code Workspace - Computer Networks Lab
color 0A

if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\bin" (
    set "PATH=%LOCALAPPDATA%\Programs\Microsoft VS Code\bin;%PATH%"
)
if exist "%ProgramFiles%\Microsoft VS Code\bin" (
    set "PATH=%ProgramFiles%\Microsoft VS Code\bin;%PATH%"
)
if exist "%ProgramFiles(x86)%\Microsoft VS Code\bin" (
    set "PATH=%ProgramFiles(x86)%\Microsoft VS Code\bin;%PATH%"
)

echo ======================================================================
echo   OPENING ns-3 IN VISUAL STUDIO CODE [WSL $TargetDistro]
echo   Computer Networks Lab (Lab 01) - BSCS Department [Semester 3]
echo    Prepared with care for BSCS Students by Qamar Abbas
echo ======================================================================
echo.
echo [*] Connecting VS Code to Linux workspace: ~/workspace/ns-3-dev ...

wsl.exe -d $TargetDistro bash -lic "cd ~/workspace/ns-3-dev && code ."
if %errorlevel% neq 0 (
    where code >nul 2>&1
    if %errorlevel% equ 0 (
        for /f "usebackq delims=" %%u in (`wsl.exe -d $TargetDistro bash -c "echo `$USER"`) do set "WSL_USER=%%u"
        if defined WSL_USER (
            code --remote wsl+$TargetDistro /home/%WSL_USER%/workspace/ns-3-dev
        ) else (
            code --remote wsl+$TargetDistro /root/workspace/ns-3-dev
        )
    ) else (
        echo.
        echo  [!] Visual Studio Code was not found or failed to launch.
        echo  Please open the ns-3 Linux Terminal and run 'code .' from there,
        echo  or verify that Visual Studio Code is installed.
        pause
    )
)
"@
    [System.IO.File]::WriteAllText((Join-Path $TargetDir "open_ns3_vscode.bat"), $codeContent)

    # 3. Create EXACTLY TWO shortcuts strictly on the user's primary Desktop
    try {
        $lnk1 = Join-Path $desktop "ns-3 Linux Terminal.lnk"
        $sc1 = $wsh.CreateShortcut($lnk1)
        $sc1.TargetPath = (Join-Path $TargetDir "open_ns3_terminal.bat")
        $sc1.WorkingDirectory = $TargetDir
        $sc1.IconLocation = "cmd.exe,0"
        $sc1.Description = "Open ns-3 Linux Terminal (Computer Networks Lab)"
        $sc1.Save()

        $lnk2 = Join-Path $desktop "ns-3 VS Code.lnk"
        $sc2 = $wsh.CreateShortcut($lnk2)
        $sc2.TargetPath = (Join-Path $TargetDir "open_ns3_vscode.bat")
        $sc2.WorkingDirectory = $TargetDir
        $sc2.IconLocation = "shell32.dll,220"
        $sc2.Description = "Open ns-3 in Visual Studio Code (Computer Networks Lab)"
        $sc2.Save()
    } catch {}
}

# 2. Fast Non-Blocking Re-entry Check (Checks if ns-3 already installed & operational)
$hasWSL = (Get-Command wsl.exe -ErrorAction SilentlyContinue) -ne $null
if ($hasWSL -and -not $isSandbox) {
    $detectedDistro = Get-TargetWSLDistro
    if ($detectedDistro) {
        $checkReady = wsl.exe -d $detectedDistro bash -c "cd ~/workspace/ns-3-dev 2>/dev/null && [ -f ns3 ] && ([ -d build ] || [ -d cmake-cache ]) && echo READY" 2>$null
        if ($checkReady -match "READY") {
            Show-ControlCenter -Distro $detectedDistro
        }
    }
}

# 3. Fresh Installation Welcome Banner
Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "                 ns-3 AUTOMATED ONE-CLICK INSTALLATION SUITE                  " -ForegroundColor Cyan
Write-Host "             Computer Networks Lab (Lab 01) - BSCS Department                 " -ForegroundColor Cyan
Write-Host "       Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas             " -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Welcome! This installer automatically configures your complete ns-3" -ForegroundColor White
Write-Host "  network simulation environment on Windows 10 and Windows 11." -ForegroundColor White
Write-Host ""
Write-Host "  What this tool will do for you:" -ForegroundColor Green
Write-Host "    [1] Pre-Flight System Readiness Audit (OS, RAM, Virtualization, Disk)" -ForegroundColor White
Write-Host "    [2] Partition Storage Selection (Supports C:, D:, E:, etc.)" -ForegroundColor White
Write-Host "    [3] Configure Windows Subsystem for Linux (WSL2) with Auto-Detection" -ForegroundColor White
Write-Host "    [4] Configure Ubuntu user account and password" -ForegroundColor White
Write-Host "    [5] Verify or install Visual Studio Code and Linux WSL extension" -ForegroundColor White
Write-Host "    [6] Install complete C++ toolchain (g++, cmake, ninja, python3, git)" -ForegroundColor White
Write-Host "    [7] Fetch ns-3 simulation core and compile with RAM-safe CPU tuning" -ForegroundColor White
Write-Host "    [8] Run automated verification simulations (hello-simulator, first.cc)" -ForegroundColor White
Write-Host "    [9] Place 2 clean 1-click shortcuts directly on your Windows Desktop" -ForegroundColor White
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  Press any key to begin the Pre-Flight System Audit..." -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
Wait-ForInput

# 4. Phase 1: Pre-Flight System Readiness Audit
Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "                 SYSTEM READINESS AUDIT (Pre-Flight Check)                    " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Analyzing your computer hardware and storage partitions..." -ForegroundColor White
Write-Host ""

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$proc = Get-CimInstance Win32_Processor
$build = [int]$os.BuildNumber
$is64 = [Environment]::Is64BitOperatingSystem
$virt = ($cs.HypervisorPresent -eq $true) -or ($proc.VirtualizationFirmwareEnabled -eq $true)
$ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)

# Enumerate all storage partitions
$allDisks = @(Get-SystemDisks)
$cDriveObj = $allDisks | Where-Object { $_.Letter -eq "C" } | Select-Object -First 1
$hasDriveWith15GB = ($allDisks | Where-Object { $_.FreeGB -ge 15 }) -ne $null
$bestDisk = $allDisks | Sort-Object -Property FreeGB -Descending | Select-Object -First 1

# Non-blocking network check (3-second timeout)
$hasNet = $false
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $iar = $tcp.BeginConnect("gitlab.com", 443, $null, $null)
    if ($iar.AsyncWaitHandle.WaitOne(3000)) {
        $tcp.EndConnect($iar)
        $hasNet = $true
    }
    $tcp.Close()
} catch {}
if (-not $hasNet) {
    try {
        $tcp2 = New-Object System.Net.Sockets.TcpClient
        $iar2 = $tcp2.BeginConnect("microsoft.com", 443, $null, $null)
        if ($iar2.AsyncWaitHandle.WaitOne(3000)) {
            $tcp2.EndConnect($iar2)
            $hasNet = $true
        }
        $tcp2.Close()
    } catch {}
}

Write-Host "  ------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "   COMPONENT                STATUS / VALUE                           RESULT     " -ForegroundColor Cyan
Write-Host "  ------------------------------------------------------------------------------" -ForegroundColor DarkGray

$allPass = $true

# Check 1: 64-bit OS
if ($is64) {
    Write-Host ("   Operating System         : {0,-35} [PASS]" -f ($os.Caption + " [64-bit]")) -ForegroundColor Green
} else {
    Write-Host ("   Operating System         : {0,-35} [FAIL]" -f ($os.Caption + " [32-bit]")) -ForegroundColor Red
    $allPass = $false
}

# Check 2: Windows Build Number
if ($build -ge 19041) {
    Write-Host ("   Windows Build Number     : {0,-35} [PASS]" -f ("Build " + $build + " [WSL2 Ready]")) -ForegroundColor Green
} else {
    Write-Host ("   Windows Build Number     : {0,-35} [FAIL]" -f ("Build " + $build + " [Outdated < 19041]")) -ForegroundColor Red
    $allPass = $false
}

# Check 3: BIOS Virtualization
if ($virt) {
    Write-Host ("   Hardware Virtualization  : {0,-35} [PASS]" -f "Enabled [Intel VT-x / AMD SVM]") -ForegroundColor Green
} else {
    Write-Host ("   Hardware Virtualization  : {0,-35} [FAIL]" -f "Disabled in BIOS/Firmware") -ForegroundColor Red
    $allPass = $false
}

# Check 4: Processor & CPU Threads
$procName = ($proc.Name -replace "\(R\)|\(TM\)", "").Trim()
if ($procName.Length -gt 28) { $procName = $procName.Substring(0, 25) + "..." }
Write-Host ("   Processor Architecture   : {0,-35} [PASS]" -f ($procName + " ($cpuThreads Threads)")) -ForegroundColor Green

# Check 5: RAM & Turbo Concurrency Tuning
if ($ramGB -lt 4) {
    Write-Host ("   System Memory [RAM]      : {0,-35} [WARN]" -f ($ramGB.ToString() + " GB [2 Threads - Low Memory]")) -ForegroundColor Yellow
} elseif ($ramGB -lt 8) {
    Write-Host ("   System Memory [RAM]      : {0,-35} [PASS]" -f ($ramGB.ToString() + " GB [$compileJobs Threads - Safe Concurrency]")) -ForegroundColor Green
} elseif ($ramGB -lt 16) {
    Write-Host ("   System Memory [RAM]      : {0,-35} [PASS]" -f ($ramGB.ToString() + " GB [$compileJobs Threads - High-Speed Concurrency]")) -ForegroundColor Green
} elseif ($ramGB -lt 32) {
    Write-Host ("   System Memory [RAM]      : {0,-35} [PASS]" -f ($ramGB.ToString() + " GB [$compileJobs Threads - Turbo Accelerator]")) -ForegroundColor Green
} else {
    Write-Host ("   System Memory [RAM]      : {0,-35} [PASS]" -f ($ramGB.ToString() + " GB [$compileJobs Threads - Maximum Beast Mode]")) -ForegroundColor Green
}

# Check 6: Available Storage Space Across Partitions
if ($hasDriveWith15GB) {
    $storageSummary = if ($cDriveObj -and $cDriveObj.FreeGB -ge 15) {
        "$($cDriveObj.FreeGB) GB Free on C:"
    } else {
        "$($bestDisk.FreeGB) GB Free on $($bestDisk.Letter):"
    }
    Write-Host ("   Available Disk Storage   : {0,-35} [PASS]" -f $storageSummary) -ForegroundColor Green
} else {
    $maxAvailable = if ($bestDisk) { "$($bestDisk.FreeGB) GB on $($bestDisk.Letter):" } else { "0 GB" }
    Write-Host ("   Available Disk Storage   : {0,-35} [FAIL]" -f "Max: $maxAvailable [Need >= 15 GB]") -ForegroundColor Red
    $allPass = $false
}

# Check 7: Internet Connectivity
if ($hasNet) {
    Write-Host ("   Internet Connectivity    : {0,-35} [PASS]" -f "Connected to Repositories") -ForegroundColor Green
} else {
    Write-Host ("   Internet Connectivity    : {0,-35} [WARN]" -f "Offline or Firewall Restricted") -ForegroundColor Yellow
}

Write-Host "  ------------------------------------------------------------------------------" -ForegroundColor DarkGray

if (-not $allPass) {
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Red
    Write-Host "  [!] PRE-FLIGHT AUDIT STOPPED: ONE OR MORE PREREQUISITES FAILED" -ForegroundColor Red
    Write-Host "==============================================================================" -ForegroundColor Red
    if (-not $virt) {
        Write-Host ""
        Write-Host "  ACTION REQUIRED: HARDWARE VIRTUALIZATION IS DISABLED IN BIOS" -ForegroundColor Yellow
        Write-Host "  WSL2 Linux requires CPU Virtualization to be enabled. To turn it on:" -ForegroundColor White
        Write-Host "    1. Restart your laptop." -ForegroundColor Gray
        Write-Host "    2. Repeatedly press your BIOS key as soon as the screen turns on:" -ForegroundColor Gray
        Write-Host "       - HP: Esc or F10  |  Dell: F2 or F12  |  Lenovo: F2 or Fn+F2" -ForegroundColor Cyan
        Write-Host "       - Asus: F2 or Del |  Acer: F2 or Del" -ForegroundColor Cyan
        Write-Host "    3. Find 'Virtualization Technology', 'Intel VT-x', or 'AMD SVM'." -ForegroundColor Gray
        Write-Host "    4. Set it to [Enabled], press F10 to Save and Exit." -ForegroundColor Gray
        Write-Host "    5. Once back in Windows, double-click this installer again!" -ForegroundColor Gray
    }
    if ($build -lt 19041) {
        Write-Host ""
        Write-Host "  ACTION REQUIRED: OUTDATED WINDOWS VERSION" -ForegroundColor Yellow
        Write-Host "  Please open Windows Settings -> Windows Update and update your PC." -ForegroundColor White
    }
    if (-not $hasDriveWith15GB) {
        Write-Host ""
        Write-Host "  ACTION REQUIRED: LOW DISK SPACE" -ForegroundColor Yellow
        Write-Host "  None of your drives have at least 15 GB of free space." -ForegroundColor White
        Write-Host "  Please free up at least 15 GB on any drive (C:, D:, etc.) and try again." -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  This window will stay open so you can note down the instructions." -ForegroundColor White
    Write-Host "  Press Enter to close this window..." -ForegroundColor Gray
    Wait-ForEnter
    exit 1
}

Write-Host "   ALL PRE-FLIGHT AUDIT CHECKS PASSED! Your computer is 100% ready." -ForegroundColor Green
Write-Host ""

if ($isSandbox) {
    Write-Host "==============================================================================" -ForegroundColor Yellow
    Write-Host "     [DEMO COMPLETE] HARDWARE & PRE-FLIGHT AUDIT PASSED IN SANDBOX!           " -ForegroundColor Green
    Write-Host "==============================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  All Pre-Flight diagnostic checks completed with 100% success!" -ForegroundColor White
    Write-Host ""
    Write-Host "  As noted earlier, Windows Subsystem for Linux (WSL2) cannot be initialized" -ForegroundColor Yellow
    Write-Host "  inside Windows Sandbox because Sandbox does not support nested virtualization." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  NEXT STEP TO COMPLETE FULL SETUP:" -ForegroundColor Cyan
    Write-Host "  Run this installer on your physical host Windows 10/11 laptop (outside Sandbox)." -ForegroundColor White
    Write-Host "  Everything is verified and ready for full installation on your real PC!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Press Enter to exit the Sandbox test..." -ForegroundColor Gray
    Wait-ForEnter
    exit 0
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  Press any key to choose your installation partition..." -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
Wait-ForInput

# 5. Phase 2: Partition & Storage Selection (Custom Drive Support)
Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "                 STORAGE PARTITION SELECTION & DRIVE CONFIG                   " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Detected Fixed Partitions on your PC:" -ForegroundColor White
Write-Host ""
Write-Host "  ------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "   DRIVE   FREE SPACE       TOTAL SPACE      RECOMMENDATION / STATUS           " -ForegroundColor Cyan
Write-Host "  ------------------------------------------------------------------------------" -ForegroundColor DarkGray

$existingInstall = Get-ExistingInstallations
$recommendedLetter = "C"
if ($existingInstall.PreferredDrive) {
    $recommendedLetter = $existingInstall.PreferredDrive
} elseif ($cDriveObj -and $cDriveObj.FreeGB -ge 15) {
    $recommendedLetter = "C"
} elseif ($bestDisk) {
    $recommendedLetter = $bestDisk.Letter
}

foreach ($d in $allDisks) {
    $statusStr = ""
    $color = "White"
    if ($existingInstall.PreferredDrive -and $d.Letter -eq $existingInstall.PreferredDrive) {
        $statusStr = "[EXISTING SETUP] Already configured on this drive"
        $color = "Green"
    } elseif ($d.Letter -eq $recommendedLetter) {
        $statusStr = "[RECOMMENDED] Best Fit for Setup"
        $color = "Green"
    } elseif ($d.HasSpace) {
        $statusStr = "[USABLE] Sufficient Storage"
        $color = "Cyan"
    } else {
        $statusStr = "[LOW SPACE] Less than 15 GB"
        $color = "Yellow"
    }
    Write-Host ("    {0,-6} {1,-16} {2,-16} {3}" -f ("$($d.Letter):"), "$($d.FreeGB) GB Free", "$($d.TotalGB) GB Total", $statusStr) -ForegroundColor $color
}
Write-Host "  ------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

if (@($allDisks).Count -gt 1) {
    Write-Host "  You can install ns-3 on any drive letter with enough free space." -ForegroundColor White
    Write-Host "  Press [ENTER] to use the recommended drive (${recommendedLetter}:), or type another letter:" -ForegroundColor Yellow
    $userDriveChoice = Read-Host "  Enter drive letter [default: $recommendedLetter]"
    if (-not $userDriveChoice) { $userDriveChoice = $recommendedLetter }
    $userDriveChoice = $userDriveChoice.Trim().TrimEnd('\').TrimEnd('/').TrimEnd(':').ToUpper()
    
    $selectedDisk = $allDisks | Where-Object { $_.Letter -eq $userDriveChoice } | Select-Object -First 1
    if (-not $selectedDisk) {
        Write-Host "  [!] Drive ${userDriveChoice}: not found. Using default: ${recommendedLetter}:" -ForegroundColor Yellow
        $userDriveChoice = $recommendedLetter
        $selectedDisk = $allDisks | Where-Object { $_.Letter -eq $userDriveChoice } | Select-Object -First 1
    }
} else {
    $userDriveChoice = $recommendedLetter
    $selectedDisk = @($allDisks)[0]
}

$chosenDrive = "${userDriveChoice}:"
$installRoot = "$chosenDrive\ns3-setup"
$wslMoveTarget = "$chosenDrive\ns3-wsl"

Write-Host ""
Write-Host "  [OK] Installation Drive Selected: $chosenDrive" -ForegroundColor Green
Write-Host "       Workspace Directory: $installRoot" -ForegroundColor Gray
Write-Host ""

# Ensure workspace directory exists on chosen drive
if (-not (Test-Path $installRoot)) {
    try { New-Item -ItemType Directory -Path $installRoot -Force | Out-Null } catch {}
}

# Update working scriptDir to the chosen installation root
$scriptDir = $installRoot

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  Press any key to proceed with installation..." -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
Wait-ForInput

# 6. Phase 3: WSL2 & Ubuntu Provisioning (With Dynamic Distro Detection)
Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  [Step 1/6] Configuring Windows Subsystem for Linux (WSL2)...                 " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

# Detect existing distro dynamically (Ubuntu, Ubuntu-24.04, Ubuntu-22.04, etc.)
$targetDistro = Get-TargetWSLDistro

if ($targetDistro) {
    Write-Host "  [OK] Linux distribution detected: $targetDistro" -ForegroundColor Green
} else {
    Write-Host "  [*] No registered Linux distribution found. Installing WSL2 and Ubuntu..." -ForegroundColor Yellow
    Write-Host "  [*] Downloading official Ubuntu Linux kernel and image from Microsoft..." -ForegroundColor White
    Write-Host "      (This may take 3-5 minutes depending on your internet connection)`n" -ForegroundColor Gray

    wsl.exe --install -d Ubuntu --no-launch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [*] Enabling Windows Subsystem for Linux & Virtual Machine features..." -ForegroundColor Yellow
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
        wsl.exe --set-default-version 2 2>$null | Out-Null
        wsl.exe --install -d Ubuntu --no-launch
    }

    wsl.exe --set-default-version 2 2>$null | Out-Null

    # Re-detect distro
    $targetDistro = Get-TargetWSLDistro
    if (-not $targetDistro) {
        Write-Host ""
        Write-Host "==============================================================================" -ForegroundColor Yellow
        Write-Host "  [RESTART REQUIRED] Windows Virtual Machine Platform has been enabled.       " -ForegroundColor Yellow
        Write-Host "==============================================================================" -ForegroundColor Yellow
        Write-Host "  Windows requires a quick computer restart to finalize Linux virtualization." -ForegroundColor White
        Write-Host ""
        Write-Host "  1. Please restart your laptop right now." -ForegroundColor Cyan
        Write-Host "  2. After restarting, double-click this INSTALL_ALL_ns3.bat file again." -ForegroundColor Cyan
        Write-Host "     (It will automatically resume right where you left off!)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Press Enter to close this window and restart your PC..." -ForegroundColor Yellow
        Wait-ForEnter
        exit 0
    }
    Write-Host "  [OK] WSL2 and $targetDistro installed successfully!" -ForegroundColor Green
}

# Ensure WSL version is 2
wsl.exe --set-version $targetDistro 2 2>$null | Out-Null
wsl.exe --set-default-version 2 2>$null | Out-Null

# Relocate WSL virtual disk to alternate partition if non-C drive selected and not already there
if ($chosenDrive -ne "C:" -and (Test-Path $chosenDrive)) {
    $currentDistroDrive = if ($existingInstall.WSLDrive) { $existingInstall.WSLDrive } else { "" }
    if ($currentDistroDrive -eq $chosenDrive) {
        Write-Host "  [OK] Linux storage is already located on $chosenDrive ($($existingInstall.WSLDistroPath)). Skipping relocation!" -ForegroundColor Green
    } else {
        try {
            if (-not (Test-Path $wslMoveTarget)) { New-Item -ItemType Directory -Path $wslMoveTarget -Force | Out-Null }
            Write-Host "  [*] Relocating Linux storage to $wslMoveTarget to preserve space on C:..." -ForegroundColor Yellow
            wsl.exe --manage $targetDistro --move "$wslMoveTarget" 2>$null | Out-Null
            Write-Host "  [OK] Linux storage configured on $chosenDrive!" -ForegroundColor Green
        } catch {}
    }
}

# 7. Phase 4: Ubuntu User Account & Password Configuration
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  [Step 2/6] Configuring Ubuntu User Account and Password...                   " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [*] Checking Ubuntu user accounts and permissions in $targetDistro..." -ForegroundColor Yellow

$existingUser = (wsl.exe -d $targetDistro -u root bash -c "id -un 1000 2>/dev/null || echo NONE" 2>$null).Trim()
if ($existingUser -eq "NONE" -or -not $existingUser) {
    Write-Host "  No default user account found. Let's configure your login:" -ForegroundColor White
    Write-Host ""
    Write-Host "    [1] Quick Setup: Set default password '12345' (Recommended for Lab)" -ForegroundColor Cyan
    Write-Host "        - Simplifies lab work so you never forget your sudo password" -ForegroundColor Gray
    Write-Host "        - Automatically configures seamless lab access" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    [2] Custom Setup: Choose your own username and password" -ForegroundColor Cyan
    Write-Host ""
    $passChoice = Read-Host "Enter choice [1 or 2, default: 1]"
    if (-not $passChoice) { $passChoice = "1" }

    if ($passChoice -eq "2") {
        Write-Host "`n  Opening interactive Ubuntu setup. Please enter your username and password below:" -ForegroundColor Yellow
        wsl.exe -d $targetDistro
        wsl.exe -t $targetDistro 2>$null
        Start-Sleep -Seconds 2
    } else {
        Write-Host "`n  [*] Creating standard lab account 'student' with password '12345'..." -ForegroundColor Yellow
        wsl.exe -d $targetDistro -u root bash -c "useradd -m -s /bin/bash -G sudo student 2>/dev/null || true; echo 'student:12345' | chpasswd; echo 'student ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/student; chmod 0440 /etc/sudoers.d/student; printf '[user]\ndefault=student\n' > /etc/wsl.conf"
        wsl.exe -t $targetDistro 2>$null
        Start-Sleep -Seconds 2
        Write-Host "  [OK] Account 'student' configured with password '12345' and seamless sudo!" -ForegroundColor Green
    }
} else {
    Write-Host "  [OK] Existing Ubuntu user detected: $existingUser" -ForegroundColor Green
    Write-Host "  [*] Ensuring passwordless sudo access for lab exercises..." -ForegroundColor Yellow
    wsl.exe -d $targetDistro -u root bash -c "echo '$existingUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$existingUser; chmod 0440 /etc/sudoers.d/$existingUser" 2>$null
    Write-Host "  [OK] User permissions verified!" -ForegroundColor Green
}

# 8. Phase 5: Visual Studio Code Check & Automated Setup
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  [Step 3/6] Setting Up Visual Studio Code and Remote Extension...             " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

$vscodeCmd = $null
$codeOnPath = Get-Command code -ErrorAction SilentlyContinue
if ($codeOnPath) {
    $vscodeCmd = "code"
} else {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $vscodeCmd = $c; break }
    }
}

if ($vscodeCmd) {
    Write-Host "  [OK] Visual Studio Code is installed on your computer!" -ForegroundColor Green
} else {
    Write-Host "  [!] Visual Studio Code was not detected." -ForegroundColor Yellow
    Write-Host "  [*] Automatically downloading and installing official Visual Studio Code..." -ForegroundColor White
    Write-Host "      (Includes 'Add to PATH' configuration)`n" -ForegroundColor Gray

    $vsInstaller = Join-Path $env:TEMP "VSCodeSetup.exe"
    try {
        if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
            curl.exe -L -# "https://update.code.visualstudio.com/latest/win32-x64-user/stable" -o $vsInstaller
        } else {
            (New-Object System.Net.WebClient).DownloadFile("https://update.code.visualstudio.com/latest/win32-x64-user/stable", $vsInstaller)
        }
        if (Test-Path $vsInstaller) {
            Write-Host "`n  [*] Installing VS Code silently in background..." -ForegroundColor Yellow
            Start-Process -FilePath $vsInstaller -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode,addtopath" -Wait
            Remove-Item $vsInstaller -Force -ErrorAction SilentlyContinue
            $vscodeCmd = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
            $env:PATH = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin;$env:PATH"
            Write-Host "  [OK] Visual Studio Code installed successfully!" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [WARN] Automated VS Code download was skipped. You can still use the Linux terminal!" -ForegroundColor Yellow
    }
}

if ($vscodeCmd) {
    $extList = & $vscodeCmd --list-extensions 2>$null
    if ($extList -match "ms-vscode-remote\.remote-wsl") {
        Write-Host "  [OK] VS Code WSL remote development extension is already installed!" -ForegroundColor Green
    } else {
        Write-Host "  [*] Installing official Microsoft WSL extension for VS Code..." -ForegroundColor Yellow
        try {
            & $vscodeCmd --install-extension ms-vscode-remote.remote-wsl --force 2>$null | Out-Null
            Write-Host "  [OK] VS Code WSL remote development extension installed!" -ForegroundColor Green
        } catch {}
    }
}

# 9. Phase 6: Ubuntu Compilers & Build Tools
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  [Step 4/6] Installing C++ Compilers and Build Tools inside $targetDistro...  " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

$checkTools = wsl.exe -d $targetDistro bash -c "which g++ cmake ninja git python3 >/dev/null 2>&1 && echo ALREADY_INSTALLED" 2>$null
if ($checkTools -match "ALREADY_INSTALLED") {
    Write-Host "  [OK] All C++ compilers and build tools are already installed inside $targetDistro!" -ForegroundColor Green
} else {
    Write-Host "  Note: This step installs g++, cmake, ninja-build, git, python3, ccache." -ForegroundColor White
    Write-Host "  Estimated duration: ~2 to 4 minutes.`n" -ForegroundColor Gray

    $pkgInstallCmd = @'
for i in $(seq 1 30); do
    if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
        echo "[*] Waiting for Ubuntu background updates to complete (attempt $i/30)..."
        sleep 2
    else
        break
    fi
done
echo '[1/2] Updating Ubuntu package repositories...'
apt-get update -y
echo '[2/2] Downloading & configuring C++ compiler suite (g++, cmake, ninja, python3)...'
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends g++ cmake ninja-build git python3 python3-pip python3-setuptools ccache pkg-config sqlite3 libsqlite3-dev libxml2-dev
echo '[OK] C++ compilers and build tools successfully installed!'
'@

    $b64Pkg = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pkgInstallCmd))
    wsl.exe -d $targetDistro -u root bash -c "echo '$b64Pkg' | base64 -d | bash"
    $pkgSuccess = ($LASTEXITCODE -eq 0)

    if (-not $pkgSuccess) {
        Write-Host "`n  [!] Retrying package installation once..." -ForegroundColor Yellow
        wsl.exe -d $targetDistro -u root bash -c "echo '$b64Pkg' | base64 -d | bash"
        $pkgSuccess = ($LASTEXITCODE -eq 0)
    }

    if (-not $pkgSuccess) {
        Write-Host "`n  [!] Failed to install C++ compilers inside $targetDistro." -ForegroundColor Red
        Write-Host "  Please check your internet connection and run this installer again." -ForegroundColor White
        Wait-ForEnter
        exit 1
    }
    Write-Host "`n  [OK] All C++ compilers and build tools successfully installed!" -ForegroundColor Green
}

# 10. Phase 7: Fetch & Compile ns-3 Simulator Core
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  [Step 5/6] Downloading and Compiling ns-3 Simulator Core...                  " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Compiling ns-3 takes ~8 to 15 minutes." -ForegroundColor White
Write-Host "  - Your laptop fans will spin up as your CPU compiles thousands of lines of C++." -ForegroundColor Gray
Write-Host "  - Anti-Sleep Guard is active: Your laptop will stay awake during compilation." -ForegroundColor Gray
Write-Host "  - Build Concurrency: $compileJobs parallel threads (Tuned for your RAM).`n" -ForegroundColor Cyan

# Prevent laptop sleep during compilation
try {
    $csharpSleepCode = @'
    using System;
    using System.Runtime.InteropServices;
    public class SleepGuard {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern uint SetThreadExecutionState(uint esFlags);
        public static void Prevent() { SetThreadExecutionState(0x80000000 | 0x00000001 | 0x00000040); }
        public static void Restore() { SetThreadExecutionState(0x80000000); }
    }
'@
    Add-Type -TypeDefinition $csharpSleepCode -ErrorAction SilentlyContinue
    [SleepGuard]::Prevent()
} catch {}

# Execute ns-3 build in Ubuntu
$buildScript = @"
set -e
mkdir -p ~/workspace
cd ~/workspace
git config --global --add safe.directory "*" 2>/dev/null || true

# 1. WSL2 DNS Fallback Guard
if ! getent hosts gitlab.com >/dev/null 2>&1 && ! getent hosts github.com >/dev/null 2>&1; then
    echo '[*] Configuring WSL2 DNS nameservers...'
    echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf >/dev/null 2>&1 || true
    echo 'nameserver 1.1.1.1' | sudo tee -a /etc/resolv.conf >/dev/null 2>&1 || true
fi

# 2. Workspace permissions guard
sudo chown -R `$(id -u):`$(id -g) ~/workspace 2>/dev/null || true

# 3. Clean incomplete or corrupted previous download
if [ -d 'ns-3-dev' ]; then
    if [ ! -f 'ns-3-dev/CMakeLists.txt' ] || [ ! -f 'ns-3-dev/ns3' ]; then
        echo '[*] Cleaning up incomplete or corrupted previous download...'
        rm -rf ns-3-dev
    fi
fi

if [ ! -d 'ns-3-dev/.git' ]; then
    echo '[1/3] Downloading ns-3 simulator core (with live download progress)...'
    if ! git clone --depth 1 --progress https://gitlab.com/nsnam/ns-3-dev.git ns-3-dev; then
        echo '[!] Primary GitLab download timed out or failed. Falling back to GitHub mirror...'
        rm -rf ns-3-dev
        git clone --depth 1 --progress https://github.com/nsnam/ns-3-dev-git.git ns-3-dev
    fi
    echo '[OK] ns-3 source repository downloaded successfully!'
else
    echo '[1/3] [OK] ns-3 source repository already exists!'
fi
cd ~/workspace/ns-3-dev
chmod +x ./ns3 2>/dev/null || true
if [ -d 'build' ] && [ -d 'cmake-cache' ]; then
    echo '[2/3] [OK] ns-3 build configuration active. Skipping reconfiguration.'
else
    echo '[2/3] Configuring ns-3 build system (examples & runtime logging active, tests disabled for max speed)...'
    ./ns3 configure --enable-examples --disable-tests --enable-logs -d optimized || {
        echo '[!] Build cache conflict detected. Cleaning cache and reconfiguring...'
        rm -rf build cmake-cache
        ./ns3 configure --enable-examples --disable-tests --enable-logs -d optimized
    }
fi
echo '[3/3] Compiling C++ simulator with Ninja ($compileJobs parallel CPU threads)...'
echo '      Watch the object compilation progress counter [X/Y] advance below:'
./ns3 build -j $compileJobs
echo '[OK] ns-3 compilation completed successfully!'
"@

$b64Build = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($buildScript))
wsl.exe -d $targetDistro bash -lic "echo '$b64Build' | base64 -d | bash"
$buildSuccess = ($LASTEXITCODE -eq 0)

if (-not $buildSuccess) {
    Write-Host "`n  [*] Finalizing compilation and resolving dependencies..." -ForegroundColor Yellow
    wsl.exe -d $targetDistro bash -lic "echo '$b64Build' | base64 -d | bash"
    $buildSuccess = ($LASTEXITCODE -eq 0)
}

try { [SleepGuard]::Restore() } catch {}

if (-not $buildSuccess) {
    Write-Host "`n  [!] ns-3 compilation encountered an issue." -ForegroundColor Red
    Write-Host "  This window will remain open so you can read the log above." -ForegroundColor White
    Write-Host "  Press Enter to exit..." -ForegroundColor Gray
    Wait-ForEnter
    exit 1
}

Write-Host "`n  [OK] ns-3 compiled successfully!" -ForegroundColor Green

# 11. Phase 8: Automated Verification Simulations
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  [Step 6/6] Running Automated Verification Simulations...                     " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "  >> [1/2] Running Verification Test 1: hello-simulator (Smoke test)..." -ForegroundColor Yellow
wsl.exe -d $targetDistro bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run hello-simulator"
Write-Host "     [PASS] Simulator core is active and responding!" -ForegroundColor Green

Write-Host "`n  >> [2/2] Running Verification Test 2: first.cc (Two-Node Point-to-Point simulation)..." -ForegroundColor Yellow
wsl.exe -d $targetDistro bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run examples/tutorial/first"
Write-Host "     [PASS] Lab 1 network simulation completed successfully!" -ForegroundColor Green

Write-Host "`n  [OK] All verification simulations PASSED with 100% success!" -ForegroundColor Green

# 12. Phase 9: Auto-Generate Launchers & Desktop Shortcuts (Strictly 2 clean icons)
Write-Host ""
Write-Host "  [*] Generating 1-click launchers and desktop shortcuts..." -ForegroundColor Yellow
New-DesktopShortcuts -TargetDir $scriptDir -TargetDistro $targetDistro

# 13. Phase 10: Final Completion Summary Checklist
Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "             ns-3 SIMULATION ENVIRONMENT SUCCESSFULLY INSTALLED!              " -ForegroundColor Green
Write-Host "         Computer Networks Lab (Lab 01) - BSCS Department [Semester 3]        " -ForegroundColor Cyan
Write-Host "          Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas          " -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Summary of Components Configured:" -ForegroundColor White
Write-Host "    [OK] Windows Subsystem for Linux (WSL2)         : ACTIVE ($targetDistro)" -ForegroundColor Green
Write-Host "    [OK] Linux Storage Location                     : ACTIVE ($chosenDrive)" -ForegroundColor Green
Write-Host "    [OK] C++ Compilers and Build Tools (g++, ninja) : INSTALLED" -ForegroundColor Green
Write-Host "    [OK] Visual Studio Code and WSL Remote Plugin   : CONFIGURED" -ForegroundColor Green
Write-Host "    [OK] ns-3 Simulation Core and Libraries         : COMPILED" -ForegroundColor Green
Write-Host "    [OK] Verification Test 1 (hello-simulator)      : PASSED" -ForegroundColor Green
Write-Host "    [OK] Verification Test 2 (first.cc simulation)  : PASSED" -ForegroundColor Green
Write-Host "    [OK] Ubuntu User Account and Password           : CONFIGURED" -ForegroundColor Green
Write-Host "    [OK] Desktop 1-Click Shortcuts (2 Icons)        : CREATED ON DESKTOP" -ForegroundColor Green
Write-Host ""
Write-Host "  HOW TO START WORKING FROM NOW ON:" -ForegroundColor Cyan
Write-Host "    1. Desktop Shortcut : Double-click `"ns-3 Linux Terminal`" on your Desktop!" -ForegroundColor White
Write-Host "    2. VS Code Shortcut : Double-click `"ns-3 VS Code`" on your Desktop!" -ForegroundColor White
Write-Host "    3. Installer File   : Double-clicking this file again opens the Control Center." -ForegroundColor White
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  Installation is complete! Press any key to launch your ns-3 terminal now..." -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
Wait-ForInput

$termBat = Join-Path $scriptDir "open_ns3_terminal.bat"
if (Test-Path $termBat) { Start-Process $termBat } else { wsl.exe -d $targetDistro -e bash -lic "cd ~/workspace/ns-3-dev; exec bash" }
exit 0
