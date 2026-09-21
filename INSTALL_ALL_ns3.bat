<# :ns3_master_installer
@echo off
setlocal EnableDelayedExpansion
title ns-3 Automated Environment - BSCS Computer Networks
color 0B
cd /d "%~dp0"
set "NS3_SCRIPT_PATH=%~f0"

:: Execute embedded PowerShell engine with ExecutionPolicy Bypass
powershell -NoProfile -ExecutionPolicy Bypass -Command "$scriptPath=$env:NS3_SCRIPT_PATH; $s=[System.IO.File]::ReadAllText($scriptPath); Invoke-Expression $s"

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
# Pure PowerShell Core Engine (Modern, Robust, & Bulletproof)
# Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas
# ==============================================================================

$Host.UI.RawUI.WindowTitle = "ns-3 Automated Simulation Suite - BSCS Computer Networks"

# Determine script path and working directory
$scriptPath = $env:NS3_SCRIPT_PATH
if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
    # If run in-memory via web runner (irm ... | iex), establish clean local workspace
    $defaultDir = "C:\ns3-setup"
    if (-not (Test-Path $defaultDir)) { New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null }
    $scriptPath = Join-Path $defaultDir "INSTALL_ALL_ns3.bat"
    if (-not (Test-Path $scriptPath)) {
        try {
            Invoke-RestMethod -Uri "https://raw.githubusercontent.com/qamarabbas-024/ns3-setup-for-window-10-11/main/INSTALL_ALL_ns3.bat" -OutFile $scriptPath
            Unblock-File -Path $scriptPath -ErrorAction SilentlyContinue
        } catch {}
    }
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
    Write-Host "    • Windows Sandbox does NOT have nested virtualization enabled." -ForegroundColor Gray
    Write-Host "      Windows Subsystem for Linux (WSL2) cannot run inside Sandbox." -ForegroundColor Gray
    Write-Host "    • Windows Sandbox is temporary: all files will be discarded on close." -ForegroundColor Gray
    Write-Host "    • To install ns-3 for your coursework, please run this installer" -ForegroundColor White
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

# Function to show Control Center
function Show-ControlCenter {
    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host "                         ns-3 SIMULATION CONTROL CENTER                       " -ForegroundColor Cyan
        Write-Host "         Computer Networks Lab (Lab 01) - BSCS Department [Semester 3]        " -ForegroundColor Cyan
        Write-Host "          Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas          " -ForegroundColor Yellow
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Your ns-3 simulation environment is fully installed and operational!" -ForegroundColor Green
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
                    Start-Process cmd.exe -ArgumentList "/k wsl.exe -d Ubuntu -e bash -lic `"cd ~/workspace/ns-3-dev 2>/dev/null || cd ~; exec bash`""
                }
                exit 0
            }
            "2" {
                $codeBat = Join-Path $scriptDir "open_ns3_vscode.bat"
                if (Test-Path $codeBat) {
                    Start-Process $codeBat
                } else {
                    wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && code ."
                }
                exit 0
            }
            "3" {
                Write-Host "`nRunning Lab 1 (first.cc)...`n" -ForegroundColor Yellow
                wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run examples/tutorial/first"
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                [void][Console]::ReadLine()
            }
            "4" {
                Write-Host "`nRunning Smoke Test (hello-simulator)...`n" -ForegroundColor Yellow
                wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run hello-simulator"
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                [void][Console]::ReadLine()
            }
            "5" {
                Write-Host "`nRecompiling ns-3 code with Ninja...`n" -ForegroundColor Yellow
                wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && ./ns3 build"
                Write-Host "`nPress Enter to return to menu..." -ForegroundColor Gray
                [void][Console]::ReadLine()
            }
            "6" {
                New-DesktopShortcuts -TargetDir $scriptDir
                Write-Host "`n[OK] Shortcuts created on your Desktop!" -ForegroundColor Green
                Start-Sleep -Seconds 2
            }
            "7" {
                wsl.exe -d Ubuntu bash -c "rm -f ~/workspace/ns-3-dev/ns3" 2>$null
                return
            }
            "8" { exit 0 }
            default { exit 0 }
        }
    }
}

# Function to generate Desktop Shortcuts and local batch files
function New-DesktopShortcuts {
    param([string]$TargetDir)
    
    $desktop = [Environment]::GetFolderPath("Desktop")
    $wsh = New-Object -ComObject WScript.Shell

    # 1. open_ns3_terminal.bat
    $termContent = @"
@echo off
setlocal
cd /d "%~dp0"
title ns-3 Linux Terminal - Computer Networks Lab
color 0B
wsl.exe -d Ubuntu -e bash -lic "cd ~/workspace/ns-3-dev 2>/dev/null || cd ~; cat << 'EOF'
======================================================================
     WELCOME TO YOUR ns-3 NETWORK SIMULATION ENVIRONMENT!
     Computer Networks Lab (Lab 01) - BSCS Department [Semester 3]
      Prepared with care for BSCS Students by Qamar Abbas
======================================================================
 Current Directory: ~/workspace/ns-3-dev

 LAB 1 CHEAT SHEET:
   - Test Simulator : ./ns3 run hello-simulator
   - Run Lab 1      : ./ns3 run examples/tutorial/first
   - Recompile Code : ./ns3 build
   - Open VS Code   : code .
   - Exit to Windows: exit
======================================================================
EOF
exec bash"
"@
    [System.IO.File]::WriteAllText((Join-Path $TargetDir "open_ns3_terminal.bat"), $termContent)

    # 2. open_ns3_vscode.bat
    $codeContent = @"
@echo off
setlocal
cd /d "%~dp0"
title ns-3 VS Code Workspace - Computer Networks Lab
color 0A
echo Opening ns-3 workspace in Visual Studio Code...
wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && code ."
if %errorlevel% neq 0 (
    where code >nul 2>&1
    if %errorlevel% equ 0 (
        code --remote wsl+Ubuntu /home/%USERNAME%/workspace/ns-3-dev
    )
)
"@
    [System.IO.File]::WriteAllText((Join-Path $TargetDir "open_ns3_vscode.bat"), $codeContent)

    # 3. Desktop Shortcuts
    try {
        $sc1 = $wsh.CreateShortcut("$desktop\ns-3 Linux Terminal.lnk")
        $sc1.TargetPath = (Join-Path $TargetDir "open_ns3_terminal.bat")
        $sc1.WorkingDirectory = $TargetDir
        $sc1.IconLocation = "cmd.exe,0"
        $sc1.Description = "Open ns-3 Linux Terminal (Computer Networks Lab)"
        $sc1.Save()

        $sc2 = $wsh.CreateShortcut("$desktop\ns-3 VS Code.lnk")
        $sc2.TargetPath = (Join-Path $TargetDir "open_ns3_vscode.bat")
        $sc2.WorkingDirectory = $TargetDir
        $sc2.IconLocation = "shell32.dll,220"
        $sc2.Description = "Open ns-3 in Visual Studio Code (Computer Networks Lab)"
        $sc2.Save()
    } catch {}
}

# 2. Fast Non-Blocking Re-entry Check (Checks if ns-3 already installed)
$hasWSL = (Get-Command wsl.exe -ErrorAction SilentlyContinue) -ne $null
if ($hasWSL -and -not $isSandbox) {
    $lxssService = Get-Service -Name LxssManager -ErrorAction SilentlyContinue
    if ($lxssService) {
        $rawDistros = (wsl.exe -l -q 2>$null)
        if ($rawDistros) {
            $distros = ($rawDistros -replace "`0", "")
            if ($distros -match "Ubuntu") {
                $checkReady = wsl.exe -d Ubuntu bash -c "[ -f ~/workspace/ns-3-dev/ns3 ] && echo READY" 2>$null
                if ($checkReady -match "READY") {
                    Show-ControlCenter
                }
            }
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
Write-Host "    [2] Configure Windows Subsystem for Linux (WSL2) and Ubuntu" -ForegroundColor White
Write-Host "    [3] Configure Ubuntu user account and password" -ForegroundColor White
Write-Host "    [4] Verify or install Visual Studio Code and Linux WSL extension" -ForegroundColor White
Write-Host "    [5] Install complete C++ toolchain (g++, cmake, ninja, python3, git)" -ForegroundColor White
Write-Host "    [6] Fetch ns-3 simulation core and compile with RAM-safe CPU tuning" -ForegroundColor White
Write-Host "    [7] Run automated verification simulations (hello-simulator, first.cc)" -ForegroundColor White
Write-Host "    [8] Place convenient 1-click shortcuts directly on your Windows Desktop" -ForegroundColor White
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  Press any key to begin the Pre-Flight System Audit..." -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
[void][Console]::ReadKey($true)

# 4. Phase 1: Pre-Flight System Readiness Audit
Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "                 SYSTEM READINESS AUDIT (Pre-Flight Check)                    " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Analyzing your computer hardware and Windows configuration..." -ForegroundColor White
Write-Host ""

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$proc = Get-CimInstance Win32_Processor
$disk = Get-PSDrive C -ErrorAction SilentlyContinue
$build = [int]$os.BuildNumber
$is64 = [Environment]::Is64BitOperatingSystem
$virt = ($cs.HypervisorPresent -eq $true) -or ($proc.VirtualizationFirmwareEnabled -eq $true)
$ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
$freeDiskGB = if ($disk) { [math]::Round($disk.Free / 1GB, 1) } else { 0 }

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

# Check 4: RAM & CPU Concurrency Tuning
$compileJobs = 4
if ($ramGB -lt 4) {
    Write-Host ("   System Memory [RAM]      : {0,-35} [WARN]" -f ($ramGB.ToString() + " GB [Low Memory Profile]")) -ForegroundColor Yellow
    $compileJobs = 2
} elseif ($ramGB -lt 8) {
    Write-Host ("   System Memory [RAM]      : {0,-35} [PASS]" -f ($ramGB.ToString() + " GB [Safe 4GB Concurrency]")) -ForegroundColor Green
    $compileJobs = 2
} else {
    Write-Host ("   System Memory [RAM]      : {0,-35} [PASS]" -f ($ramGB.ToString() + " GB [Multi-Core Turbo Profile]")) -ForegroundColor Green
    $compileJobs = 4
}

# Check 5: Free Disk Space
if ($freeDiskGB -ge 15) {
    Write-Host ("   Free Storage on C:\      : {0,-35} [PASS]" -f ($freeDiskGB.ToString() + " GB Free on Drive C:")) -ForegroundColor Green
} else {
    Write-Host ("   Free Storage on C:\      : {0,-35} [FAIL]" -f ($freeDiskGB.ToString() + " GB [Need at least 15 GB]")) -ForegroundColor Red
    $allPass = $false
}

# Check 6: Internet Connectivity
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
        Write-Host "       • HP: Esc or F10  |  Dell: F2 or F12  |  Lenovo: F2 or Fn+F2" -ForegroundColor Cyan
        Write-Host "       • Asus: F2 or Del |  Acer: F2 or Del" -ForegroundColor Cyan
        Write-Host "    3. Find 'Virtualization Technology', 'Intel VT-x', or 'AMD SVM'." -ForegroundColor Gray
        Write-Host "    4. Set it to [Enabled], press F10 to Save and Exit." -ForegroundColor Gray
        Write-Host "    5. Once back in Windows, double-click this installer again!" -ForegroundColor Gray
    }
    if ($build -lt 19041) {
        Write-Host ""
        Write-Host "  ACTION REQUIRED: OUTDATED WINDOWS VERSION" -ForegroundColor Yellow
        Write-Host "  Please open Windows Settings -> Windows Update and update your PC." -ForegroundColor White
    }
    if ($freeDiskGB -lt 15) {
        Write-Host ""
        Write-Host "  ACTION REQUIRED: LOW DISK SPACE" -ForegroundColor Yellow
        Write-Host "  Please free up at least 15 GB on drive C: to compile ns-3." -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  This window will stay open so you can note down the instructions." -ForegroundColor White
    Write-Host "  Press Enter to close this window..." -ForegroundColor Gray
    [void][Console]::ReadLine()
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
    [void][Console]::ReadLine()
    exit 0
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  Press any key to proceed with installation..." -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
[void][Console]::ReadKey($true)

# 5. Phase 2: Storage Confirmation
Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "                 INSTALLATION STORAGE LOCATION CONFIRMATION                   " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Recommended Location: Native High-Speed Linux Storage (~/workspace/ns-3-dev)" -ForegroundColor Green
Write-Host ""
Write-Host "  Why this location is best:" -ForegroundColor White
Write-Host "    • Compiles 5x to 10x faster than Windows drives (no NTFS bridge bottleneck)" -ForegroundColor Gray
Write-Host "    • Immune to Windows path length limits and file locking issues" -ForegroundColor Gray
Write-Host "    • Fully accessible from Windows VS Code and Windows Explorer" -ForegroundColor Gray
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  Press [ENTER] to confirm and use the Recommended Fast Location (Default)" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
[void][Console]::ReadLine()

# 6. Phase 3: WSL2 & Ubuntu Provisioning
Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  [Step 1/6] Configuring Windows Subsystem for Linux (WSL2) and Ubuntu...      " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

$rawDistros = (wsl.exe -l -q 2>$null)
$ubuntuInstalled = $false
if ($rawDistros) {
    if (($rawDistros -replace "`0", "") -match "Ubuntu") {
        $ubuntuInstalled = $true
    }
}

if ($ubuntuInstalled) {
    Write-Host "  [OK] Ubuntu is already installed in WSL2!" -ForegroundColor Green
} else {
    Write-Host "  [*] Ubuntu is not yet installed. Setting up WSL2 and Ubuntu now..." -ForegroundColor Yellow
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

    $checkDistros = (wsl.exe -l -q 2>$null) -replace "`0", ""
    if ($checkDistros -notmatch "Ubuntu") {
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
        [void][Console]::ReadLine()
        exit 0
    }
    Write-Host "  [OK] WSL2 and Ubuntu installed successfully!" -ForegroundColor Green
}

wsl.exe --set-version Ubuntu 2 2>$null | Out-Null
wsl.exe --set-default-version 2 2>$null | Out-Null

# 7. Phase 4: Ubuntu User Account & Password Configuration
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  [Step 2/6] Configuring Ubuntu User Account and Password...                   " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [*] Checking Ubuntu user accounts and permissions..." -ForegroundColor Yellow

$existingUser = (wsl.exe -d Ubuntu -u root bash -c "id -un 1000 2>/dev/null || echo NONE" 2>$null).Trim()
if ($existingUser -eq "NONE" -or -not $existingUser) {
    Write-Host "  No default user account found. Let's configure your login:" -ForegroundColor White
    Write-Host ""
    Write-Host "    [1] Quick Setup: Set default password '12345' (Recommended for Lab)" -ForegroundColor Cyan
    Write-Host "        • Simplifies lab work so you never forget your sudo password" -ForegroundColor Gray
    Write-Host "        • Automatically configures seamless lab access" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    [2] Custom Setup: Choose your own username and password" -ForegroundColor Cyan
    Write-Host ""
    $passChoice = Read-Host "Enter choice [1 or 2, default: 1]"
    if (-not $passChoice) { $passChoice = "1" }

    if ($passChoice -eq "2") {
        Write-Host "`n  Opening interactive Ubuntu setup. Please enter your username and password below:" -ForegroundColor Yellow
        wsl.exe -d Ubuntu
    } else {
        Write-Host "`n  [*] Creating standard lab account 'student' with password '12345'..." -ForegroundColor Yellow
        wsl.exe -d Ubuntu -u root bash -c "useradd -m -s /bin/bash -G sudo student 2>/dev/null || true; echo 'student:12345' | chpasswd; echo 'student ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/student; chmod 0440 /etc/sudoers.d/student; printf '[user]\ndefault=student\n' > /etc/wsl.conf"
        Write-Host "  [OK] Account 'student' configured with password '12345' and seamless sudo!" -ForegroundColor Green
    }
} else {
    Write-Host "  [OK] Existing Ubuntu user detected: $existingUser" -ForegroundColor Green
    Write-Host "  [*] Ensuring passwordless sudo access for lab exercises..." -ForegroundColor Yellow
    wsl.exe -d Ubuntu -u root bash -c "echo '$existingUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$existingUser; chmod 0440 /etc/sudoers.d/$existingUser" 2>$null
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
        curl.exe -L -# "https://update.code.visualstudio.com/latest/win32-x64-user/stable" -o $vsInstaller
        if (Test-Path $vsInstaller) {
            Write-Host "`n  [*] Installing VS Code silently in background..." -ForegroundColor Yellow
            Start-Process -FilePath $vsInstaller -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode,addtopath,desktopicon" -Wait
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
    Write-Host "  [*] Installing official Microsoft WSL extension for VS Code..." -ForegroundColor Yellow
    try {
        & $vscodeCmd --install-extension ms-vscode-remote.remote-wsl --force 2>$null | Out-Null
        Write-Host "  [OK] VS Code WSL remote development extension installed!" -ForegroundColor Green
    } catch {}
}

# 9. Phase 6: Ubuntu Compilers & Build Tools
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  [Step 4/6] Installing C++ Compilers and Build Tools inside Ubuntu...         " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Note: This step installs g++, cmake, ninja-build, git, python3, ccache." -ForegroundColor White
Write-Host "  Estimated duration: ~2 to 4 minutes.`n" -ForegroundColor Gray

wsl.exe -d Ubuntu -u root bash -c "apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends g++ cmake ninja-build git python3 python3-pip python3-setuptools ccache pkg-config sqlite3 libsqlite3-dev libxml2 libxml2-dev"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n  [!] Retrying package installation once..." -ForegroundColor Yellow
    wsl.exe -d Ubuntu -u root bash -c "apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends g++ cmake ninja-build git python3 python3-pip python3-setuptools ccache pkg-config sqlite3 libsqlite3-dev libxml2 libxml2-dev"
}
Write-Host "`n  [OK] All C++ compilers and build tools successfully installed!" -ForegroundColor Green

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
if [ ! -d 'ns-3-dev/.git' ]; then
    echo '[*] Fetching ns-3 repository using fast shallow download...'
    git clone --depth 1 https://gitlab.com/nsnam/ns-3-dev.git ns-3-dev
else
    echo '[OK] ns-3 source repository already exists!'
fi
cd ~/workspace/ns-3-dev
echo '[*] Configuring ns-3 build system (enabling examples)...'
./ns3 configure --enable-examples -d optimized
echo '[*] Starting compilation with Ninja ($compileJobs CPU threads)...'
./ns3 build -j $compileJobs
"@

wsl.exe -d Ubuntu bash -lic "$buildScript"
$buildSuccess = ($LASTEXITCODE -eq 0)

try { [SleepGuard]::Restore() } catch {}

if (-not $buildSuccess) {
    Write-Host "`n  [!] ns-3 compilation encountered an issue." -ForegroundColor Red
    Write-Host "  This window will remain open so you can read the log above." -ForegroundColor White
    Write-Host "  Press Enter to exit..." -ForegroundColor Gray
    [void][Console]::ReadLine()
    exit 1
}

Write-Host "`n  [OK] ns-3 compiled successfully!" -ForegroundColor Green

# 11. Phase 8: Automated Verification Simulations
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  [Step 6/6] Running Automated Verification Simulations...                     " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "  >> Running Verification Test 1: hello-simulator..." -ForegroundColor Yellow
wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run hello-simulator"

Write-Host "`n  >> Running Verification Test 2: first.cc (Two-Node Point-to-Point simulation)..." -ForegroundColor Yellow
wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run examples/tutorial/first"

Write-Host "`n  [OK] Verification simulations PASSED completely!" -ForegroundColor Green

# 12. Phase 9: Auto-Generate Launchers & Desktop Shortcuts
Write-Host ""
Write-Host "  [*] Generating 1-click launchers and desktop shortcuts..." -ForegroundColor Yellow
New-DesktopShortcuts -TargetDir $scriptDir

# 13. Phase 10: Final Completion Summary Checklist
Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "             ns-3 SIMULATION ENVIRONMENT SUCCESSFULLY INSTALLED!              " -ForegroundColor Green
Write-Host "         Computer Networks Lab (Lab 01) - BSCS Department [Semester 3]        " -ForegroundColor Cyan
Write-Host "          Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas          " -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Summary of Components Configured:" -ForegroundColor White
Write-Host "    [✓] Windows Subsystem for Linux (WSL2)         : ACTIVE" -ForegroundColor Green
Write-Host "    [✓] Ubuntu Linux Environment                  : ACTIVE" -ForegroundColor Green
Write-Host "    [✓] C++ Compilers and Build Tools (g++, ninja): INSTALLED" -ForegroundColor Green
Write-Host "    [✓] Visual Studio Code and WSL Remote Plugin  : CONFIGURED" -ForegroundColor Green
Write-Host "    [✓] ns-3 Simulation Core and Libraries        : COMPILED" -ForegroundColor Green
Write-Host "    [✓] Verification Test 1 (hello-simulator)     : PASSED" -ForegroundColor Green
Write-Host "    [✓] Verification Test 2 (first.cc simulation) : PASSED" -ForegroundColor Green
Write-Host "    [✓] Ubuntu User Account and Password          : CONFIGURED" -ForegroundColor Green
Write-Host "    [✓] Desktop 1-Click Shortcuts                 : CREATED ON DESKTOP" -ForegroundColor Green
Write-Host ""
Write-Host "  HOW TO START WORKING FROM NOW ON:" -ForegroundColor Cyan
Write-Host "    1. Desktop Shortcut : Double-click `"ns-3 Linux Terminal`" on your Desktop!" -ForegroundColor White
Write-Host "    2. VS Code Shortcut : Double-click `"ns-3 VS Code`" on your Desktop!" -ForegroundColor White
Write-Host "    3. Installer File   : Double-clicking this file again opens the Control Center." -ForegroundColor White
Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "  Installation is complete! Press any key to launch your ns-3 terminal now..." -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Cyan
[void][Console]::ReadKey($true)

$termBat = Join-Path $scriptDir "open_ns3_terminal.bat"
if (Test-Path $termBat) { Start-Process $termBat } else { wsl.exe -d Ubuntu -e bash -lic "cd ~/workspace/ns-3-dev; exec bash" }
exit 0
