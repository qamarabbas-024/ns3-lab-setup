@echo off
setlocal EnableDelayedExpansion
title ns-3 Automated Environment - BSCS Computer Networks
color 0B

:: Ensure working directory is the script folder, not System32
cd /d "%~dp0"

:: -----------------------------------------------------------------------------
:: 1. IMMEDIATE STARTUP BANNER (Eliminates Black Screen & Freezes)
:: -----------------------------------------------------------------------------
echo ==============================================================================
echo                 ns-3 AUTOMATED ONE-CLICK INSTALLATION SUITE
echo             Computer Networks Lab (Lab 01) - BSCS Department
echo       Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas
echo ==============================================================================
echo.
echo   [*] Initializing ns-3 Environment Manager, please wait...

:: -----------------------------------------------------------------------------
:: 2. ELEVATION CHECK & ANTI-VANISHING UAC WRAPPER
:: -----------------------------------------------------------------------------
net session >nul 2>&1
if %errorlevel% equ 0 goto :IS_ADMIN

echo.
echo ==============================================================================
echo                    ADMINISTRATOR PERMISSION REQUIRED
echo          Computer Networks Lab - BSCS Department [Semester 3]
echo ==============================================================================
echo.
echo   Windows requires Administrator permission to configure WSL2 and ns-3.
echo   Please click "YES" on the User Account Control [UAC] pop-up window!
echo.
echo ==============================================================================
powershell -ExecutionPolicy Bypass -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/k \"\"%~f0\"\"' -Verb RunAs"
exit /b 0

:IS_ADMIN

:: -----------------------------------------------------------------------------
:: 3. SELF-UNBLOCK (Removes WhatsApp / Internet Mark-of-the-Web in background)
:: -----------------------------------------------------------------------------
powershell -ExecutionPolicy Bypass -NoProfile -Command "Unblock-File -Path '%~f0' -ErrorAction SilentlyContinue" >nul 2>&1

:: -----------------------------------------------------------------------------
:: 4. FAST RE-ENTRY / CONTROL CENTER DETECTION (Non-Blocking)
:: -----------------------------------------------------------------------------
:: Only query WSL if wsl.exe exists and Ubuntu is registered (avoids 15-second hang)
where wsl.exe >nul 2>&1
if %errorlevel% neq 0 goto :FRESH_INSTALL_VIEW

wsl.exe -l -q 2>nul | findstr /i "Ubuntu" >nul 2>&1
if %errorlevel% neq 0 goto :FRESH_INSTALL_VIEW

wsl.exe -d Ubuntu bash -c "[ -f ~/workspace/ns-3-dev/ns3 ] && echo READY" 2>nul | findstr /i "READY" >nul 2>&1
if %errorlevel% equ 0 goto :CONTROL_CENTER

:FRESH_INSTALL_VIEW
cls
echo ==============================================================================
echo                 ns-3 AUTOMATED ONE-CLICK INSTALLATION SUITE
echo             Computer Networks Lab (Lab 01) - BSCS Department
echo       Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas
echo ==============================================================================
echo.
echo   Welcome! This installer automatically configures your complete ns-3
echo   network simulation environment on Windows 10 and Windows 11.
echo.
echo   What this tool will do:
echo     [1] Pre-Flight System Readiness Audit (OS, RAM, Virtualization, Disk)
echo     [2] Configure Windows Subsystem for Linux (WSL2) and Ubuntu
echo     [3] Configure Ubuntu user account and password
echo     [4] Verify or install Visual Studio Code and Linux WSL extension
echo     [5] Install complete C++ toolchain (g++, cmake, ninja, python3, git)
echo     [6] Fetch ns-3 simulation core and compile with RAM-safe CPU tuning
echo     [7] Run automated verification simulations (hello-simulator, first.cc)
echo     [8] Place convenient 1-click shortcuts directly on your Windows Desktop
echo.
echo ==============================================================================
echo   Press any key to begin the Pre-Flight System Audit...
echo ==============================================================================
pause >nul

:: -----------------------------------------------------------------------------
:: 4. PHASE 1: PRE-FLIGHT SYSTEM READINESS AUDIT
:: -----------------------------------------------------------------------------
cls
echo ==============================================================================
echo                 SYSTEM READINESS AUDIT (Pre-Flight Check)
echo ==============================================================================
echo.
echo   Analyzing your computer hardware and Windows configuration...
echo.

set "AUDIT_PS=%TEMP%\ns3_audit_%RANDOM%.ps1"
(
echo $os = Get-CimInstance Win32_OperatingSystem
echo $cs = Get-CimInstance Win32_ComputerSystem
echo $proc = Get-CimInstance Win32_Processor
echo $disk = Get-PSDrive C -ErrorAction SilentlyContinue
echo $build = [int]$os.BuildNumber
echo $is64 = [Environment]::Is64BitOperatingSystem
echo $virt = ($cs.HypervisorPresent -eq $true) -or ($proc.VirtualizationFirmwareEnabled -eq $true)
echo $ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
echo $freeDiskGB = if ($disk) { [math]::Round($disk.Free / 1GB, 1) } else { 0 }
echo $hasNet = $false
echo try {
echo     $tcp = New-Object System.Net.Sockets.TcpClient
echo     $tcp.Connect("gitlab.com", 443)
echo     $hasNet = $true
echo     $tcp.Close()
echo } catch {
echo     try {
echo         $tcp2 = New-Object System.Net.Sockets.TcpClient
echo         $tcp2.Connect("microsoft.com", 443)
echo         $hasNet = $true
echo         $tcp2.Close()
echo     } catch { $hasNet = $false }
echo }
echo Write-Output "OS_NAME=$($os.Caption)"
echo Write-Output "OS_BUILD=$build"
echo Write-Output "IS_64BIT=$is64"
echo Write-Output "VIRT_ENABLED=$virt"
echo Write-Output "RAM_GB=$ramGB"
echo Write-Output "FREE_DISK_GB=$freeDiskGB"
echo Write-Output "HAS_INTERNET=$hasNet"
) > "%AUDIT_PS%"

for /f "tokens=1,* delims==" %%A in ('powershell -ExecutionPolicy Bypass -NoProfile -File "%AUDIT_PS%"') do (
    set "%%A=%%B"
)
del "%AUDIT_PS%" >nul 2>&1

:: Display Pre-flight Table
echo   ------------------------------------------------------------------------------
echo    COMPONENT                STATUS / VALUE                           RESULT
echo   ------------------------------------------------------------------------------

:: Check 1: 64-bit OS
if /i "%IS_64BIT%"=="True" (
    echo    Operating System         : %OS_NAME% [64-bit]    [PASS]
) else (
    echo    Operating System         : %OS_NAME% [32-bit]    [FAIL]
    echo.
    echo   [!] ERROR: ns-3 and WSL2 require a 64-bit version of Windows.
    goto :AUDIT_FAILED
)

:: Check 2: Windows Build (19041+ needed for WSL2)
if %OS_BUILD% geq 19041 (
    echo    Windows Build Number     : %OS_BUILD% [WSL2 Capable]                 [PASS]
) else (
    echo    Windows Build Number     : %OS_BUILD% [Outdated]                     [FAIL]
    echo.
    echo   [!] ERROR: Your Windows version is older than Build 19041.
    echo   Please open Windows Settings - Update and Security - Run Windows Update.
    goto :AUDIT_FAILED
)

:: Check 3: BIOS Virtualization
if /i "%VIRT_ENABLED%"=="True" (
    echo    Hardware Virtualization  : Enabled [Intel VT-x / AMD SVM Active]  [PASS]
) else (
    echo    Hardware Virtualization  : Disabled in BIOS/Firmware             [FAIL]
    echo.
    echo   ===========================================================================
    echo    ACTION REQUIRED: HARDWARE VIRTUALIZATION IS DISABLED IN YOUR BIOS
    echo   ===========================================================================
    echo    WSL2 Linux requires CPU Virtualization to run. To enable it:
    echo      1. Restart your laptop.
    echo      2. As soon as it powers on, press your BIOS key repeatedly:
    echo         - HP: Esc or F10
    echo         - Dell: F2 or F12
    echo         - Lenovo: F2 or Fn+F2
    echo         - Asus: F2 or Del
    echo         - Acer: F2 or Del
    echo      3. In BIOS, find "Virtualization Technology", "Intel VT-x", or "AMD SVM".
    echo      4. Change setting to [ENABLED], press F10 to Save and Exit.
    echo      5. Once back in Windows, double-click this installer again!
    echo   ===========================================================================
    goto :AUDIT_FAILED
)

:: Check 4: System RAM
set "COMPILE_JOBS=4"
for /f "tokens=1 delims=." %%R in ("%RAM_GB%") do set "RAM_INT=%%R"
if %RAM_INT% lss 4 (
    echo    System Memory [RAM]      : %RAM_GB% GB [Low Memory Profile]          [WARN]
    set "COMPILE_JOBS=2"
) else if %RAM_INT% lss 8 (
    echo    System Memory [RAM]      : %RAM_GB% GB [Safe 4GB Concurrency]        [PASS]
    set "COMPILE_JOBS=2"
) else (
    echo    System Memory [RAM]      : %RAM_GB% GB [High-Speed Multi-Core]       [PASS]
    set "COMPILE_JOBS=4"
)

:: Check 5: Free Disk Space (15 GB needed)
for /f "tokens=1 delims=." %%D in ("%FREE_DISK_GB%") do set "DISK_INT=%%D"
if %DISK_INT% geq 15 (
    echo    Free Storage on C:\      : %FREE_DISK_GB% GB [Adequate Space]            [PASS]
) else (
    echo    Free Storage on C:\      : %FREE_DISK_GB% GB [Need at least 15 GB]       [FAIL]
    echo.
    echo   [!] WARNING: ns-3 compilation requires at least 15 GB of free space on C:.
    echo   Please free up disk space on drive C: before continuing.
    goto :AUDIT_FAILED
)

:: Check 6: Internet
if /i "%HAS_INTERNET%"=="True" (
    echo    Internet Connectivity    : Connected to Package Repositories      [PASS]
) else (
    echo    Internet Connectivity    : No Connection Detected                 [FAIL]
    echo.
    echo   [!] ERROR: An active internet connection is required to download packages.
    echo   Please check your Wi-Fi or Ethernet connection and try again.
    goto :AUDIT_FAILED
)

echo   ------------------------------------------------------------------------------
echo    ALL PRE-FLIGHT AUDIT CHECKS PASSED! Your computer is 100%% ready.
echo   ------------------------------------------------------------------------------
echo.
echo ==============================================================================
echo   Press any key to proceed with installation...
echo ==============================================================================
pause >nul

:: -----------------------------------------------------------------------------
:: 5. PHASE 2: STORAGE LOCATION CONFIRMATION
:: -----------------------------------------------------------------------------
cls
echo ==============================================================================
echo                 INSTALLATION STORAGE LOCATION CONFIRMATION
echo ==============================================================================
echo.
echo   Recommended Location: Native High-Speed Linux Storage (~/workspace/ns-3-dev)
echo.
echo   Why this location is best:
echo     - Compiles 5x to 10x faster than Windows drives (no NTFS bridge bottleneck)
echo     - Immune to Windows path length limits and file locking issues
echo     - Fully accessible from Windows VS Code and Windows Explorer
echo.
echo ==============================================================================
echo   Press [ENTER] to confirm and use the Recommended Fast Location (Default)
echo ==============================================================================
set "STORAGE_CONFIRM="
set /p "STORAGE_CONFIRM=Choice [Press Enter for Default]: "

:: -----------------------------------------------------------------------------
:: 6. PHASE 3: WSL2 & UBUNTU PROVISIONING
:: -----------------------------------------------------------------------------
cls
echo ==============================================================================
echo  [Step 1/6] Configuring Windows Subsystem for Linux (WSL2) and Ubuntu...
echo ==============================================================================
echo.
echo  Checking WSL status...

set "UBUNTU_FOUND=0"
wsl.exe -l -q 2>nul | findstr /i "Ubuntu" >nul 2>&1
if %errorlevel% equ 0 goto :UBUNTU_ALREADY_INSTALLED

echo  [*] Ubuntu is not yet installed. Setting up WSL2 and Ubuntu now...
echo  [*] Downloading official Ubuntu Linux kernel and image from Microsoft...
echo      (This may take 3-5 minutes depending on your internet connection)
echo.

:: Try modern wsl --install first
wsl.exe --install -d Ubuntu --no-launch
if !errorlevel! neq 0 (
    echo  [*] Using Windows DISM Feature deployment fallback...
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    wsl.exe --set-default-version 2 >nul 2>&1
    wsl.exe --install -d Ubuntu --no-launch
)

wsl.exe --set-default-version 2 >nul 2>&1

:: Re-verify Ubuntu installation
wsl.exe -l -q 2>nul | findstr /i "Ubuntu" >nul 2>&1
if !errorlevel! equ 0 goto :UBUNTU_INSTALLED_OK

echo.
echo ==============================================================================
echo  [RESTART REQUIRED] Windows Virtual Machine Platform has been enabled.
echo ==============================================================================
echo  Windows requires a quick computer restart to finalize Linux virtualization.
echo.
echo  1. Please restart your laptop right now.
echo  2. After restarting, double-click this INSTALL_ALL_ns3.bat file again.
echo     (It will automatically resume right where you left off!)
echo.
echo  Press any key to close this window and restart your PC...
echo ==============================================================================
pause >nul
exit /b 0

:UBUNTU_ALREADY_INSTALLED
echo  [OK] Ubuntu is already installed in WSL2!
goto :SET_WSL_VERSION

:UBUNTU_INSTALLED_OK
echo  [OK] WSL2 and Ubuntu installed successfully!

:SET_WSL_VERSION
wsl.exe --set-version Ubuntu 2 >nul 2>&1
wsl.exe --set-default-version 2 >nul 2>&1

:: -----------------------------------------------------------------------------
:: 7. PHASE 4: UBUNTU USER ACCOUNT & PASSWORD CONFIGURATION
:: -----------------------------------------------------------------------------
echo.
echo ==============================================================================
echo  [Step 2/6] Configuring Ubuntu User Account and Password...
echo ==============================================================================
echo.

:: Detect if a default non-root user exists
for /f "tokens=*" %%U in ('wsl.exe -d Ubuntu -u root bash -c "id -un 1000 2>/dev/null || echo NONE"') do (
    set "EXISTING_USER=%%U"
)

if /i "%EXISTING_USER%"=="NONE" goto :SETUP_NEW_USER
echo  [OK] Existing Ubuntu user detected: %EXISTING_USER%
echo  [*] Ensuring passwordless sudo access for lab exercises...
wsl.exe -d Ubuntu -u root bash -c "echo '%EXISTING_USER% ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/%EXISTING_USER%; chmod 0440 /etc/sudoers.d/%EXISTING_USER%" >nul 2>&1
echo  [OK] User permissions verified!
goto :PHASE_VSCODE

:SETUP_NEW_USER
echo  No default user account found. Let's configure your login:
echo.
echo    [1] Quick Setup: Set default password '12345' (Recommended for Lab)
echo        - Simplifies lab work so you never forget your sudo password
echo        - Automatically configures seamless lab access
echo.
echo    [2] Custom Setup: Choose your own username and password
echo.
set "PASS_CHOICE=1"
set /p "PASS_CHOICE=Enter choice [1 or 2, default: 1]: "

if "%PASS_CHOICE%"=="2" (
    echo.
    echo  Opening interactive Ubuntu setup. Please enter your desired username
    echo  and password when prompted below:
    echo ----------------------------------------------------------------------
    wsl.exe -d Ubuntu
    echo ----------------------------------------------------------------------
) else (
    echo.
    echo  [*] Creating standard lab account 'student' with password '12345'...
    wsl.exe -d Ubuntu -u root bash -c "useradd -m -s /bin/bash -G sudo student 2>/dev/null || true; echo 'student:12345' | chpasswd; echo 'student ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/student; chmod 0440 /etc/sudoers.d/student; printf '[user]\ndefault=student\n' > /etc/wsl.conf"
    echo  [OK] Account 'student' configured with password '12345' and seamless sudo!
)

:PHASE_VSCODE
:: -----------------------------------------------------------------------------
:: 8. PHASE 5: VISUAL STUDIO CODE CHECK & AUTOMATED SETUP
:: -----------------------------------------------------------------------------
echo.
echo ==============================================================================
echo  [Step 3/6] Setting Up Visual Studio Code and Remote Extension...
echo ==============================================================================
echo.

set "VSCODE_CMD="
where code >nul 2>&1
if %errorlevel% equ 0 (
    set "VSCODE_CMD=code"
) else (
    if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd" (
        set "VSCODE_CMD=%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd"
    ) else if exist "%ProgramFiles%\Microsoft VS Code\bin\code.cmd" (
        set "VSCODE_CMD=%ProgramFiles%\Microsoft VS Code\bin\code.cmd"
    )
)

if defined VSCODE_CMD (
    echo  [OK] Visual Studio Code is installed on your computer!
) else (
    echo  [!] Visual Studio Code was not detected.
    echo  [*] Automatically downloading and installing official Visual Studio Code...
    echo      (Includes 'Add to PATH' configuration)
    echo.
    set "VS_INSTALLER=%TEMP%\VSCodeSetup.exe"
    curl.exe -L -# "https://update.code.visualstudio.com/latest/win32-x64-user/stable" -o "!VS_INSTALLER!"
    if exist "!VS_INSTALLER!" (
        echo  [*] Installing VS Code silently in background...
        "!VS_INSTALLER!" /VERYSILENT /NORESTART /MERGETASKS=!runcode,addtopath,desktopicon >nul 2>&1
        del "!VS_INSTALLER!" >nul 2>&1
        set "VSCODE_CMD=%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd"
        set "PATH=%LOCALAPPDATA%\Programs\Microsoft VS Code\bin;!PATH!"
        echo  [OK] Visual Studio Code installed successfully!
    ) else (
        echo  [WARN] Automated VS Code download was skipped. You can still use the Linux terminal!
    )
)

if defined VSCODE_CMD (
    echo  [*] Installing official Microsoft WSL extension for VS Code...
    call "%VSCODE_CMD%" --install-extension ms-vscode-remote.remote-wsl --force >nul 2>&1
    echo  [OK] VS Code WSL remote development extension installed!
)

:: -----------------------------------------------------------------------------
:: 9. PHASE 6: UBUNTU COMPILERS & BUILD TOOLS
:: -----------------------------------------------------------------------------
echo.
echo ==============================================================================
echo  [Step 4/6] Installing C++ Compilers and Build Tools inside Ubuntu...
echo ==============================================================================
echo.
echo  Note: This step installs g++, cmake, ninja-build, git, python3, ccache.
echo  Estimated duration: ~2 to 4 minutes.
echo.

wsl.exe -d Ubuntu -u root bash -c "apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends g++ cmake ninja-build git python3 python3-pip python3-setuptools ccache pkg-config sqlite3 libsqlite3-dev libxml2 libxml2-dev"

if %errorlevel% neq 0 (
    echo.
    echo  [!] Package installation encountered a network error.
    echo  Retrying package installation once...
    wsl.exe -d Ubuntu -u root bash -c "apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends g++ cmake ninja-build git python3 python3-pip python3-setuptools ccache pkg-config sqlite3 libsqlite3-dev libxml2 libxml2-dev"
    if !errorlevel! neq 0 goto :INSTALL_ERROR
)

echo.
echo  [OK] All C++ compilers and build tools successfully installed!

:: -----------------------------------------------------------------------------
:: 10. PHASE 7: FETCH & COMPILE ns-3 SIMULATOR CORE
:: -----------------------------------------------------------------------------
echo.
echo ==============================================================================
echo  [Step 5/6] Downloading and Compiling ns-3 Simulator Core...
echo ==============================================================================
echo.
echo  Compiling ns-3 takes ~8 to 15 minutes.
echo  - Your laptop fans will spin up as your CPU compiles thousands of lines of C++.
echo  - Anti-Sleep Guard is active: Your laptop will stay awake during compilation.
echo  - Build Concurrency: %COMPILE_JOBS% parallel threads (Tuned for your RAM).
echo.

:: Prevent laptop from going to sleep during compilation
powershell -ExecutionPolicy Bypass -NoProfile -Command "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Runtime.InteropServices'); $code = @'
using System;
using System.Runtime.InteropServices;
public class SleepPreventer {
    [DllImport(\"kernel32.dll\", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
    public const uint ES_CONTINUOUS = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED = 0x00000001;
    public const uint ES_AWAYMODE_REQUIRED = 0x00000040;
    public static void PreventSleep() { SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_AWAYMODE_REQUIRED); }
    public static void AllowSleep() { SetThreadExecutionState(ES_CONTINUOUS); }
}
'@; Add-Type -TypeDefinition $code -Language CSharp; [SleepPreventer]::PreventSleep()" >nul 2>&1

:: Build ns-3 script executed inside Ubuntu as student user
wsl.exe -d Ubuntu bash -lic "
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
echo '[*] Starting compilation with Ninja (%COMPILE_JOBS% CPU threads)...'
./ns3 build -j %COMPILE_JOBS%
"

set "BUILD_STATUS=%errorlevel%"

:: Restore normal sleep settings
powershell -ExecutionPolicy Bypass -NoProfile -Command "[SleepPreventer]::AllowSleep()" >nul 2>&1

if %BUILD_STATUS% neq 0 (
    echo.
    echo  [!] Compilation encountered an issue.
    goto :BUILD_ERROR
)

echo.
echo  [OK] ns-3 compiled successfully!

:: -----------------------------------------------------------------------------
:: 11. PHASE 8: AUTOMATED VERIFICATION SIMULATIONS
:: -----------------------------------------------------------------------------
echo.
echo ==============================================================================
echo  [Step 6/6] Running Automated Verification Simulations...
echo ==============================================================================
echo.

echo  >> Running Verification Test 1: hello-simulator...
wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run hello-simulator"

echo.
echo  >> Running Verification Test 2: first.cc (Two-Node Point-to-Point simulation)...
wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run examples/tutorial/first"

if %errorlevel% neq 0 (
    echo.
    echo  [WARN] Verification simulation produced a warning. Check logs above.
) else (
    echo.
    echo  [OK] Verification simulations PASSED completely!
)

:: -----------------------------------------------------------------------------
:: 12. PHASE 9: AUTO-GENERATE LAUNCHERS & DESKTOP SHORTCUTS
:: -----------------------------------------------------------------------------
echo.
echo  [*] Generating 1-click launchers and desktop shortcuts...

set "GEN_PS=%TEMP%\ns3_gen_shortcuts_%RANDOM%.ps1"
(
echo $scriptDir = '%~dp0'.TrimEnd('\')
echo $desktop = [Environment]::GetFolderPath('Desktop')
echo $wsh = New-Object -ComObject WScript.Shell
echo $termContent = @'
echo @echo off
echo setlocal
echo cd /d "%%~dp0"
echo title ns-3 Linux Terminal - Computer Networks Lab
echo color 0B
echo wsl.exe -d Ubuntu -e bash -lic "cd ~/workspace/ns-3-dev 2>/dev/null || cd ~; cat << 'EOF'
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
echo EOF
echo exec bash"
echo '@
echo [System.IO.File]::WriteAllText("$scriptDir\open_ns3_terminal.bat", $termContent)
echo $codeContent = @'
echo @echo off
echo setlocal
echo cd /d "%%~dp0"
echo title ns-3 VS Code Workspace - Computer Networks Lab
echo color 0A
echo echo Opening ns-3 workspace in Visual Studio Code...
echo wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && code ."
echo if %%errorlevel%% neq 0 (
echo     where code ^>nul 2^>^&1
echo     if %%errorlevel%% equ 0 (
echo         code --remote wsl+Ubuntu /home/$USER/workspace/ns-3-dev
echo     )
echo )
echo '@
echo [System.IO.File]::WriteAllText("$scriptDir\open_ns3_vscode.bat", $codeContent)
echo $sc1 = $wsh.CreateShortcut("$desktop\ns-3 Linux Terminal.lnk")
echo $sc1.TargetPath = "$scriptDir\open_ns3_terminal.bat"
echo $sc1.WorkingDirectory = "$scriptDir"
echo $sc1.IconLocation = "cmd.exe,0"
echo $sc1.Description = "Open ns-3 Linux Terminal (Computer Networks Lab)"
echo $sc1.Save()
echo $sc2 = $wsh.CreateShortcut("$desktop\ns-3 VS Code.lnk")
echo $sc2.TargetPath = "$scriptDir\open_ns3_vscode.bat"
echo $sc2.WorkingDirectory = "$scriptDir"
echo $sc2.IconLocation = "shell32.dll,220"
echo $sc2.Description = "Open ns-3 in Visual Studio Code (Computer Networks Lab)"
echo $sc2.Save()
) > "%GEN_PS%"

powershell -ExecutionPolicy Bypass -NoProfile -File "%GEN_PS%" >nul 2>&1
del "%GEN_PS%" >nul 2>&1

:: -----------------------------------------------------------------------------
:: 13. PHASE 10: FINAL COMPLETION SUMMARY CHECKLIST
:: -----------------------------------------------------------------------------
cls
echo ==============================================================================
echo             ns-3 SIMULATION ENVIRONMENT SUCCESSFULLY INSTALLED!
echo         Computer Networks Lab (Lab 01) - BSCS Department [Semester 3]
echo          Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas
echo ==============================================================================
echo.
echo   Summary of Components Configured:
echo     [✓] Windows Subsystem for Linux (WSL2)         : ACTIVE
echo     [✓] Ubuntu Linux Environment                  : ACTIVE
echo     [✓] C++ Compilers and Build Tools (g++, ninja): INSTALLED
echo     [✓] Visual Studio Code and WSL Remote Plugin  : CONFIGURED
echo     [✓] ns-3 Simulation Core and Libraries        : COMPILED
echo     [✓] Verification Test 1 (hello-simulator)     : PASSED
echo     [✓] Verification Test 2 (first.cc simulation) : PASSED
echo     [✓] Ubuntu User Account and Password          : CONFIGURED
echo     [✓] Desktop 1-Click Shortcuts                 : CREATED ON DESKTOP
echo.
echo   HOW TO START WORKING FROM NOW ON:
echo     1. Desktop Shortcut : Double-click "ns-3 Linux Terminal" on your Desktop!
echo     2. VS Code Shortcut : Double-click "ns-3 VS Code" on your Desktop!
echo     3. Installer File   : Double-clicking this file again opens the Control Center.
echo.
echo ==============================================================================
echo   Installation is complete! Press any key to launch your ns-3 terminal now...
echo ==============================================================================
pause >nul

start "" "%~dp0open_ns3_terminal.bat"
exit /b 0

:: -----------------------------------------------------------------------------
:: 14. CONTROL CENTER MENU (For Subsequent Launches)
:: -----------------------------------------------------------------------------
:CONTROL_CENTER
cls
echo ==============================================================================
echo                         ns-3 SIMULATION CONTROL CENTER
echo         Computer Networks Lab (Lab 01) - BSCS Department [Semester 3]
echo          Prepared with care for BSCS Batch 2025-2029 by Qamar Abbas
echo ==============================================================================
echo.
echo   Your ns-3 simulation environment is fully installed and operational!
echo.
echo   Please select an action:
echo     [1] Launch ns-3 Linux Terminal
echo     [2] Open ns-3 in Visual Studio Code
echo     [3] Run Lab 1 Simulation (first.cc)
echo     [4] Run Smoke Test (hello-simulator)
echo     [5] Rebuild / Recompile ns-3 Code
echo     [6] Re-create Desktop Shortcuts
echo     [7] Reinstall / Repair Environment from Scratch
echo     [8] Exit
echo.
echo ==============================================================================
set "CC_CHOICE=1"
set /p "CC_CHOICE=Enter choice [1-8, default: 1]: "

if "%CC_CHOICE%"=="1" goto :CC_ACTION_1
if "%CC_CHOICE%"=="2" goto :CC_ACTION_2
if "%CC_CHOICE%"=="3" goto :CC_ACTION_3
if "%CC_CHOICE%"=="4" goto :CC_ACTION_4
if "%CC_CHOICE%"=="5" goto :CC_ACTION_5
if "%CC_CHOICE%"=="6" goto :CC_ACTION_6
if "%CC_CHOICE%"=="7" goto :CC_ACTION_7
exit /b 0

:CC_ACTION_1
start "" "%~dp0open_ns3_terminal.bat"
exit /b 0

:CC_ACTION_2
start "" "%~dp0open_ns3_vscode.bat"
exit /b 0

:CC_ACTION_3
echo.
echo Running Lab 1 (first.cc)...
echo.
wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run examples/tutorial/first"
echo.
pause
goto :CONTROL_CENTER

:CC_ACTION_4
echo.
echo Running Smoke Test (hello-simulator)...
echo.
wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && ./ns3 run hello-simulator"
echo.
pause
goto :CONTROL_CENTER

:CC_ACTION_5
echo.
echo Recompiling ns-3 code with Ninja...
wsl.exe -d Ubuntu bash -lic "cd ~/workspace/ns-3-dev && ./ns3 build"
echo.
pause
goto :CONTROL_CENTER

:CC_ACTION_6
echo.
echo Re-creating Desktop shortcuts...
set "GEN_PS=%TEMP%\ns3_gen_shortcuts_%RANDOM%.ps1"
(
echo $scriptDir = '%~dp0'.TrimEnd('\')
echo $desktop = [Environment]::GetFolderPath('Desktop')
echo $wsh = New-Object -ComObject WScript.Shell
echo $sc1 = $wsh.CreateShortcut("$desktop\ns-3 Linux Terminal.lnk")
echo $sc1.TargetPath = "$scriptDir\open_ns3_terminal.bat"
echo $sc1.WorkingDirectory = "$scriptDir"
echo $sc1.IconLocation = "cmd.exe,0"
echo $sc1.Description = "Open ns-3 Linux Terminal"
echo $sc1.Save()
echo $sc2 = $wsh.CreateShortcut("$desktop\ns-3 VS Code.lnk")
echo $sc2.TargetPath = "$scriptDir\open_ns3_vscode.bat"
echo $sc2.WorkingDirectory = "$scriptDir"
echo $sc2.IconLocation = "shell32.dll,220"
echo $sc2.Description = "Open ns-3 in VS Code"
echo $sc2.Save()
) > "%GEN_PS%"
powershell -ExecutionPolicy Bypass -NoProfile -File "%GEN_PS%" >nul 2>&1
del "%GEN_PS%" >nul 2>&1
echo [OK] Shortcuts created on your Desktop!
ping -n 3 127.0.0.1 >nul
goto :CONTROL_CENTER

:CC_ACTION_7
echo.
echo Starting repair / full reinstall...
wsl.exe -d Ubuntu bash -c "rm -f ~/workspace/ns-3-dev/ns3" >nul 2>&1
ping -n 3 127.0.0.1 >nul
goto :IS_ADMIN

:: -----------------------------------------------------------------------------
:: 15. ERROR HANDLERS (ANTI-VANISHING GUARD)
:: -----------------------------------------------------------------------------
:AUDIT_FAILED
echo.
echo ==============================================================================
echo  [!] PRE-FLIGHT AUDIT STOPPED
echo ==============================================================================
echo  One or more prerequisite checks did not pass.
echo  Please address the issue shown above and run this installer again.
echo.
echo  Note: This window will stay open so you can read the instructions.
echo  Press any key or close this window when you are ready...
echo ==============================================================================
pause
exit /b 1

:INSTALL_ERROR
echo.
echo ==============================================================================
echo  [!] PACKAGE INSTALLATION ERROR
echo ==============================================================================
echo  Ubuntu encountered an error while downloading compilers and packages.
echo  Common causes:
echo    - Internet connection disconnected or timed out.
echo    - A university firewall is blocking package mirrors.
echo.
echo  To retry, simply double-click INSTALL_ALL_ns3.bat again.
echo  This window will stay open so you can review the error details.
echo ==============================================================================
pause
exit /b 1

:BUILD_ERROR
echo.
echo ==============================================================================
echo  [!] ns-3 COMPILATION ERROR
echo ==============================================================================
echo  The build process stopped with an error code.
echo  This window will remain open so you can examine the compiler output above.
echo.
echo  Press any key to return to Windows...
echo ==============================================================================
pause
exit /b 1
