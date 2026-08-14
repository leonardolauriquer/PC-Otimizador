@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title PC Otimizador Pro
cd /d "%~dp0"
color 0B

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo  Solicitando Administrador...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

:MAIN
cls
echo.
echo   ============================================================
echo        PC OTIMIZADOR PRO  v4
echo   ============================================================
echo.
echo     1. Limpeza Segura ^(recomendado^)
echo     2. Turbo / Gamer
echo     3. Reparar Internet
echo     4. Preset Completo
echo     5. Notebook ^(bateria / equilibrado^)
echo     6. Personalizar
echo     7. Varrer + estimar MB ^(nao apaga^)
echo     8. Dry-run Limpeza Segura ^(simular^)
echo     9. Agendar limpeza semanal
echo     R. Remover agendamento
echo     G. Interface grafica
echo     0. Sair
echo.
set /p "OP=  Opcao > "

if "%OP%"=="1" goto P_SAFE
if "%OP%"=="2" goto P_GAMER
if "%OP%"=="3" goto P_NET
if "%OP%"=="4" goto P_FULL
if "%OP%"=="5" goto P_NOTE
if "%OP%"=="6" goto CUSTOM
if "%OP%"=="7" goto SCAN
if "%OP%"=="8" goto DRY
if "%OP%"=="9" goto SCHED
if /i "%OP%"=="R" goto UNSCHED
if /i "%OP%"=="G" goto GUI
if "%OP%"=="0" goto FIM
goto MAIN

:P_SAFE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset safe
goto MAIN
:P_GAMER
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset gamer
goto MAIN
:P_NET
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset net
goto MAIN
:P_FULL
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset full
goto MAIN
:P_NOTE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset notebook
goto MAIN
:CUSTOM
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode custom
goto MAIN
:SCAN
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode scan
goto MAIN
:DRY
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset safe -DryRun -AutoYes
pause
goto MAIN
:SCHED
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode schedule -AutoYes
pause
goto MAIN
:UNSCHED
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode unschedule -AutoYes
pause
goto MAIN
:GUI
if exist "%~dp0PC-Otimizador.exe" (
  start "" "%~dp0PC-Otimizador.exe"
) else if exist "%~dp0PC-Otimizador.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0PC-Otimizador.ps1"
) else (
  echo GUI nao encontrada.
  pause
)
goto MAIN
:FIM
echo   Ate mais!
timeout /t 1 >nul
exit /b 0
