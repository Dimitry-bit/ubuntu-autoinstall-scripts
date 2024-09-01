@echo off
setlocal enabledelayedexpansion

set "SCRIPT_NAME=%~n0"

rem Validation thresholds
set /A RAM_THRESHOLD_MB=4096
set /A CPU_PHYSICAL_CORES_THRESHOLD=4
set /A FREE_SPACE_THRESHOLD_MB=40960

rem Installation conf variables
set "VIRTUAL_BOX_SRC=%VBOX_MSI_INSTALL_PATH%"
set "ADDITIONS_PATH=%VBOX_MSI_INSTALL_PATH%VBoxGuestAdditions.iso"
set "machine_name=Ubuntu 24-04 (OSC)"
set "machine_dest=%UserProfile%\VirtualBox VMs"
set "iso_src=.\ubuntu-24.04-desktop-amd64-autoinstall.iso"
set /A machine_physical_cores=%CPU_PHYSICAL_CORES_THRESHOLD%
set /A machine_ram_mb=%RAM_THRESHOLD_MB%
set /A machine_disk_size_mb=25000

call :parse_arguments %* && call :validate_specs
if !errorlevel! equ 0 (
    rem Check if a machine with the given name already exists
    VBoxManage showvminfo "!machine_name!" > nul 2>&1

    if !errorlevel! equ 0 (
        echo Found "!machine_name!".
    ) else (
        echo Creating "!machine_name!", "!machine_dest!\!machine_name!".

        rem Create and register VM
        VBoxManage createvm ^
            --name "!machine_name!" ^
            --ostype Ubuntu_64 ^
            --register ^
            --basefolder "!machine_dest!"

        echo Creating Disk Controllers.

        rem Create SATA controller
        VBoxManage createhd --filename "!machine_dest!\!machine_name!\!machine_name!.vdi" --size %machine_disk_size_mb% --format VDI
        VBoxManage storagectl "!machine_name!" --name "SATA Controller" --add sata --controller IntelAhci
        VBoxManage storageattach "!machine_name!" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "!machine_dest!\!machine_name!\!machine_name!.vdi"

        rem Create IDE controller
        VBoxManage storagectl "!machine_name!" --name "IDE Controller" --add ide --controller PIIX4
        VBoxManage modifyvm "!machine_name!" --boot1 dvd --boot2 disk --boot3 none --boot4 none
    )

    echo Configuring "!machine_name!".

    rem Configure CPU, Memory and VRAM
    VBoxManage modifyvm "!machine_name!" --ioapic on
    VBoxManage modifyvm "!machine_name!" --cpus !machine_physical_cores!
    VBoxManage modifyvm "!machine_name!" --memory !machine_ram_mb! --vram 128

    echo Starting unattended installation of "!machine_name!".

    rem Install OS with guest additions
    rem NOTE: VBoxManager unattended configure parameters are ignored, Ubuntu does not use 'DebianInstallerPreseed'
    VBoxManage unattended install "!machine_name!" ^
        --iso="!iso_src!" ^
        --additions-iso="%ADDITIONS_PATH%" ^
        --extra-install-kernel-parameters="quiet autoinstall ds=nocloud\;s=/cdrom/desktop" ^
        --install-additions ^
        --start-vm=gui
)

( echo %cmdcmdline% | findstr /l %comspec% >nul 2>&1 ) && pause
exit /b 0

:help
echo Usage: %SCRIPT_NAME% [OPTION]
echo Installes an unattended Linux ISO.
echo.
echo Options:
echo   --output DIRECTORY        set generated VM output path
echo   --name   TEXT             set generated VM name
echo   --iso    ISO_FILE         set unattended installation iso
echo   --help                    display help text and exit
goto :eof

:log
setlocal
set msg=%~1
if /I "%2"=="PASS" (
    echo [32m pass: %msg% [0m
) else if /I "%2"=="FAIL" (
    echo [31merror: %msg% [0m
) else if /I "%2"=="PANIC" (
    echo [31mpanic: %msg% [0m
) else if /I "%2"=="WARN" (
    echo [33m warn: %msg% [0m
) else (
    echo %msg%
)
endlocal
goto :eof

:parse_arguments
:loop
if NOT "%1"=="" (
    if "%1"=="--output" (
        shift
        call set "machine_dest=%%~1"
    ) else if "%1"=="--iso" (
        shift
        call set "iso_src=%%~1"
    ) else if "%1"=="--name" (
        shift
        call set "machine_name=%%~1"
    ) else if "%1"=="--help" (
        call :help
        exit /b 1
    ) else (
        call :log "unkown flag '%1'." fail
        call :help
        exit /b 2
    )

    shift
    goto :loop
)
goto :eof

:validate_specs
set /a error=0

echo Starting validation.

rem Retrieve the number of CPU cores using WMIC
for /F "tokens=2 delims==" %%a in ('wmic cpu get NumberOfCores /value') do set CPU_PHYSICAL_CORES=%%a

rem Querying RAM size in bytes
for /F "tokens=2 delims==" %%a in ('wmic ComputerSystem get TotalPhysicalMemory /value') do set RAM_SIZE_BYTES=%%a

rem Get machine_dest drive letter
for %%l in (!machine_dest!) do set dest_drive_letter=%%~dl

rem Get the free space of C drive in bytes using WMIC
for /F "tokens=2 delims==" %%a in ('wmic logicaldisk where "DeviceID='%dest_drive_letter%'" get FreeSpace /value') do set DEST_FREE_SPACE_BYTES=%%a

set /A RAM_SIZE_MB=%RAM_SIZE_BYTES:~0,-4% / (1049)
set /A DEST_FREE_SPACE_MB=%DEST_FREE_SPACE_BYTES:~0,-4% / (1049)

rem Check for VirtualBox
if "%VIRTUAL_BOX_SRC%"=="" (
    call :log "Failed to find VirtualBox installation." fail
    set /a error=1
) else (
    call :log "Found VirtualBox installtion. '%VIRTUAL_BOX_SRC%'." pass
    set "PATH=%PATH%;%VIRTUAL_BOX_SRC%"
)

if %cpu_physical_cores% gtr %CPU_PHYSICAL_CORES_THRESHOLD% (
    set /a machine_physical_cores=%CPU_PHYSICAL_CORES_THRESHOLD%
    call :log "available CPU cores '%cpu_physical_cores% cores'; recommended '%CPU_PHYSICAL_CORES_THRESHOLD%+ cores'." pass
) else (
    set /a machine_physical_cores=%cpu_physical_cores% / 2
    call :log "available CPU cores '%cpu_physical_cores%' does not meet the recommended spec '%CPU_PHYSICAL_CORES_THRESHOLD%+ cores', defaulting to '!machine_physical_cores! cores'." warn
)

if %RAM_SIZE_MB% gtr %RAM_THRESHOLD_MB% (
    set /a machine_ram_mb=%RAM_THRESHOLD_MB%
    call :log "available memory '%RAM_SIZE_MB% MB'; recommended '%RAM_THRESHOLD_MB%+ MB'." pass
) else (
    set /a machine_ram_mb=%RAM_SIZE_MB% / 2
    call :log "available memory '%RAM_SIZE_MB% MB' does not meet the recommended spec '%RAM_THRESHOLD_MB%+ MB', defaulting to '!machine_ram_mb! MB'." warn
)

if %DEST_FREE_SPACE_MB% lss %FREE_SPACE_THRESHOLD_MB% (
    call :log "insufficient disk space. Require '%FREE_SPACE_THRESHOLD_MB% MB'; available '%DEST_FREE_SPACE_MB% MB'." fail
    set /a error=1
) else (
    call :log "available free space in %dest_drive_letter% drive '%DEST_FREE_SPACE_MB% MB'; require '%FREE_SPACE_THRESHOLD_MB% MB'." pass
)

exit /b !error!
goto :eof
