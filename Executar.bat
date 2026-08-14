@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title PC Otimizador Pro
cd /d "%~dp0"
color 0B

:: ---- Admin ----
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo.
  echo  Solicitando permissao de Administrador...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

:MAIN
cls
echo.
echo   ============================================================
echo        PC OTIMIZADOR PRO
echo        Hierarquia completa — tudo pelo terminal
echo   ============================================================
echo.
echo   Nao apaga Documentos, Fotos, Downloads nem senhas.
echo.
echo   ------------------------------------------------------------
echo    MENU PRINCIPAL
echo   ------------------------------------------------------------
echo.
echo     1. Limpeza Segura ^(recomendado^)     [1 clique]
echo     2. Modo Turbo / Gamer
echo     3. Reparar Internet
echo     4. Preset Completo
echo     5. Personalizar ^(menu avancado^)
echo     6. So varrer ^(medir espaco, nao apaga^)
echo     7. Interface grafica ^(janela^)
echo     0. Sair
echo.
echo   ------------------------------------------------------------
echo    Dica: se nao souber o que escolher, digite 1
echo   ------------------------------------------------------------
echo.
set /p "OP=  Opcao > "

if "%OP%"=="1" goto PRESET_SAFE
if "%OP%"=="2" goto PRESET_GAMER
if "%OP%"=="3" goto PRESET_NET
if "%OP%"=="4" goto PRESET_FULL
if "%OP%"=="5" goto CUSTOM
if "%OP%"=="6" goto SCAN
if "%OP%"=="7" goto GUI
if "%OP%"=="0" goto FIM
if /i "%OP%"=="s" goto FIM
goto MAIN

:PRESET_SAFE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset safe
goto MAIN

:PRESET_GAMER
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset gamer
goto MAIN

:PRESET_NET
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset net
goto MAIN

:PRESET_FULL
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Preset full
goto MAIN

:CUSTOM
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode custom
goto MAIN

:SCAN
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Otimizador-CLI.ps1" -Mode scan
goto MAIN

:GUI
if not exist "%~dp0PC-Otimizador.ps1" (
  echo  Interface grafica nao encontrada.
  pause
  goto MAIN
)
echo  Abrindo interface grafica...
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0PC-Otimizador.ps1"
goto MAIN

:FIM
echo.
echo   Ate mais!
timeout /t 1 >nul
endlocal
exit /b 0
