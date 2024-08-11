@echo off

REM Validation thresholds
set /A RAM_THRESHOLD_MB=4096
set /A CPU_PHYSICAL_CORES_THRESHOLD=4
set /A FREE_SPACE_THRESHOLD_MB=40960
set IS_ERROR=0

REM Installation conf variables
set "VIRTUAL_BOX_SRC=%VBOX_MSI_INSTALL_PATH%"
set "ADDITIONS_PATH=%VBOX_MSI_INSTALL_PATH%VBoxGuestAdditions.iso"
set /A MACHINE_PHYSICAL_CORES=2
set /A MACHINE_RAM_MB=2096
set /A MACHINE_DISK_SIZE_MB=25000
set "MACHINE_NAME=Ubuntu 24-04 (OSC)"
set "MACHINE_DEST=%UserProfile%\VirtualBox VMs"
set "ISO_SRC=.\ubuntu-24.04-desktop-amd64-autoinstall.iso"

REM Retrieve the number of CPU cores using WMIC
for /F "tokens=2 delims==" %%A IN ('wmic cpu get NumberOfCores /value') do set "CPU_PHYSICAL_CORES=%%A"

REM Querying RAM size in bytes
for /F "tokens=2 delims==" %%A IN ('wmic ComputerSystem get TotalPhysicalMemory /value') do set RAM_SIZE_BYTES=%%A

REM Get the free space of C drive in bytes using WMIC
for /F "tokens=2 delims==" %%A IN ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value') do set C_FREE_SPACE_BYTES=%%A

set /A RAM_SIZE_MB=%RAM_SIZE_BYTES:~0,-4% / (1049)
set /A C_FREE_SPACE_MB=%C_FREE_SPACE_BYTES:~0,-4% / (1049)

echo Starting validation.

REM Check for VirtualBox
if "%VIRTUAL_BOX_SRC%"=="" (
    echo [31m[FAIL]: Failed to find VirtualBox installation. [0m
    set IS_ERROR=1
) else (
    echo [32m[PASS]: Found VirtualBox installtion. '%VIRTUAL_BOX_SRC%'. [0m
    set "PATH=%PATH%;%VIRTUAL_BOX_SRC%"
)

if %CPU_PHYSICAL_CORES% LSS %CPU_PHYSICAL_CORES_THRESHOLD% (
    echo [31m[FAIL]: CPU has less than '%CPU_PHYSICAL_CORES_THRESHOLD%' cores, cores:'%CPU_PHYSICAL_CORES%'. [0m
    set IS_ERROR=1
) else (
    echo [32m[PASS]: Found '%CPU_PHYSICAL_CORES%' cores. REQUIRE: '%CPU_PHYSICAL_CORES_THRESHOLD% or more'. [0m
)

if %RAM_SIZE_MB% LSS %RAM_THRESHOLD_MB% (
    echo [31m[FAIL]: Physical memory is less than '%RAM_THRESHOLD_MB% MB', memory:'%RAM_SIZE_MB% MB'. [0m
    set IS_ERROR=1
) else (
    echo [32m[PASS]: Found '%RAM_SIZE_MB% MB'. REQUIRE: '%RAM_THRESHOLD_MB% MB or more'. [0m
)

if %C_FREE_SPACE_MB% LSS %FREE_SPACE_THRESHOLD_MB% (
    echo [31m[FAIL]: C drive has less than '%FREE_SPACE_THRESHOLD_MB% MB' of free space, available:'%C_FREE_SPACE_MB% MB'. [0m
    set IS_ERROR=1
) else (
    echo [32m[PASS]: Found '%C_FREE_SPACE_MB% MB' free in C drive. REQUIRE: '%FREE_SPACE_THRESHOLD_MB% MB or more'. [0m
)

if %IS_ERROR%==1 (
    echo [31mFound 1 or more errors, exiting... [0m
) else (
    REM Check if a machine with the given name already exists
    VBoxManage showvminfo "%MACHINE_NAME%" > nul 2>&1
    if %errorlevel%==0 (
        echo Found "%MACHINE_NAME%".
    ) else (
        echo Creating "%MACHINE_NAME%", "%MACHINE_DEST%\%MACHINE_NAME%".

        REM Create and register VM
        VBoxManage createvm ^
            --name "%MACHINE_NAME%" ^
            --ostype Ubuntu_64 ^
            --register ^
            --basefolder "%MACHINE_DEST%"

        echo Creating Disk Controllers.

        REM Create SATA controller
        VBoxManage createhd --filename "%MACHINE_DEST%\%MACHINE_NAME%\%MACHINE_NAME%.vdi" --size %MACHINE_DISK_SIZE_MB% --format VDI
        VBoxManage storagectl "%MACHINE_NAME%" --name "SATA Controller" --add sata --controller IntelAhci
        VBoxManage storageattach "%MACHINE_NAME%" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "%MACHINE_DEST%\%MACHINE_NAME%\%MACHINE_NAME%.vdi"

        REM Create IDE controller
        VBoxManage storagectl "%MACHINE_NAME%" --name "IDE Controller" --add ide --controller PIIX4
        VBoxManage modifyvm "%MACHINE_NAME%" --boot1 dvd --boot2 disk --boot3 none --boot4 none
    )

    echo Configuring "%MACHINE_NAME%".

    REM Configure CPU, Memory and VRAM
    VBoxManage modifyvm "%MACHINE_NAME%" --ioapic on
    VBoxManage modifyvm "%MACHINE_NAME%" --cpus %MACHINE_PHYSICAL_CORES%
    VBoxManage modifyvm "%MACHINE_NAME%" --memory %MACHINE_RAM_MB% --vram 128

    echo Starting unattended installation of "%MACHINE_NAME%".

    REM Install OS with guest additions
    REM NOTE: VBoxManager unattended configure parameters are ignored, Ubuntu does not use 'DebianInstallerPreseed'
    VBoxManage unattended install "%MACHINE_NAME%" ^
        --iso="%ISO_SRC%" ^
        --additions-iso="%ADDITIONS_PATH%" ^
        --extra-install-kernel-parameters="quiet autoinstall ds=nocloud\;s=/cdrom/desktop" ^
        --install-additions ^
        --start-vm=gui

    echo Goodbye...
)

pause
